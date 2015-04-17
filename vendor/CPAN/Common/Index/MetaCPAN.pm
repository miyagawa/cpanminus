use 5.008001;
use strict;
use warnings;

package CPAN::Common::Index::MetaCPAN;
# ABSTRACT: Search index via MetaCPAN
# VERSION

use parent 'CPAN::Common::Index';

use Class::Tiny qw/uri include_dev/;

use Carp;
use CPAN::Meta::Requirements;
use HTTP::Tiny;
use JSON::PP ();
use Time::Local ();
use version;

=attr uri

A URI for the endpoint of MetaCPAN. The default is L<http://api.metacpan.org/v0/>.

=cut

=attr include_dev

Whether an index should include dev releases on PAUSE. Defaults to false.

=cut

sub BUILD {
    my $self = shift;
    my $uri  = $self->uri;
    $uri = "http://api.metacpan.org/v0/"
      unless defined $uri;
    # ensure URI ends in '/'
    $uri =~ s{/?$}{/};
    $self->uri($uri);
    return;
}

sub search_packages {
    my ( $self, $args ) = @_;
    Carp::croak("Argument to search_packages must be hash reference")
      unless ref $args eq 'HASH';

    my $range;
    if ( $args->{version} ) {
        $range = "== $args->{version}";
    } elsif ( $args->{version_range} ) {
        $range = $args->{version_range};
    }

    my @filter = $self->_maturity_filter($args->{package}, $range);

    my $query = { filtered => {
        (@filter ? (filter => { and => \@filter }) : ()),
        query => { nested => {
            score_mode => 'max',
            path => 'module',
            query => { custom_score => {
                metacpan_script => "score_version_numified",
                query => { constant_score => {
                    filter => { and => [
                        { term => { 'module.authorized' => JSON::PP::true() } },
                        { term => { 'module.indexed' => JSON::PP::true() } },
                        { term => { 'module.name' => $args->{package} } },
                        $self->_version_to_query($args->{package}, $range),
                    ] }
                } },
            } },
        } },
    } };

    my $module_uri = $self->uri . "file/_search?source=";
    $module_uri .= $self->_encode_json({
        query => $query,
        fields => [ 'date', 'release', 'author', 'module', 'status' ],
    });

    my($release, $author, $module_version);

    my $res = HTTP::Tiny->new->get($module_uri);
    return unless $res->{success};

    my $module_meta = eval { JSON::PP::decode_json($res->{content}) };

    my $file = $self->_find_best_match($module_meta);
    if ($file) {
        $release = $file->{release};
        $author = $file->{author};
        my $module_matched = (grep { $_->{name} eq $args->{package} } @{$file->{module}})[0];
        $module_version = $module_matched->{version};
    }

    return unless $release;

    my $dist_uri = $self->uri . "release/_search?source=";
    $dist_uri .= $self->_encode_json({
        filter => { and => [
            { term => { 'release.name' => $release } },
            { term => { 'release.author' => $author } },
        ]},
        fields => [ 'download_url' ],
    });

    $res = HTTP::Tiny->new->get($dist_uri);
    return unless $res->{success};

    my $dist_meta = eval { JSON::PP::decode_json($res->{content}) };

    if ($dist_meta) {
        $dist_meta = $dist_meta->{hits}{hits}[0]{fields};
    }

    if ($dist_meta && $dist_meta->{download_url}) {
        (my $distfile = $dist_meta->{download_url}) =~ s!.+/authors/id/\w/\w\w/!!;

        my $res = {
            package => $args->{package},
            version => $module_version,
            uri => "cpan:///distfile/$distfile",
        };

        if ($file->{status} eq 'backpan') {
            $res->{download_uri} = $self->_download_uri("http://backpan.perl.org", $distfile);
        } elsif ($self->_parse_date($file->{date}) > time() - 24 * 60 * 60) {
            $res->{download_uri} = $self->_download_uri("http://cpan.metacpan.org", $distfile);
        }

        return $res;
    }

    return;
}

sub _parse_date {
    my($self, $date) = @_;
    my @date = $date =~ /^(\d{4})-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)(?:\.\d+)?Z$/;
    Time::Local::timegm($date[5], $date[4], $date[3], $date[2], $date[1] - 1, $date[0] - 1900);
}

sub _download_uri {
    my($self, $base, $distfile) = @_;
    join "/", $base, "authors/id", substr($distfile, 0, 1), substr($distfile, 0, 2), $distfile;
}

sub _encode_json {
    my($self, $data) = @_;
    my $json = JSON::PP::encode_json($data);
    $json =~ s/([^a-zA-Z0-9_\-.])/uc sprintf("%%%02x",ord($1))/eg;
    $json;
}

sub _version_to_query {
    my($self, $module, $version) = @_;

    return () unless $version;

    my $requirements = CPAN::Meta::Requirements->new;
    $requirements->add_string_requirement($module, $version || '0');

    my $req = $requirements->requirements_for_module($module);

    if ($req =~ s/^==\s*//) {
        return {
            term => { 'module.version' => $req },
        };
    } elsif ($req !~ /\s/) {
        return {
            range => { 'module.version_numified' => { 'gte' => $self->_numify($req) } },
        };
    } else {
        my %ops = qw(< lt <= lte > gt >= gte);
        my(%range, @exclusion);
        my @requirements = split /,\s*/, $req;
        for my $r (@requirements) {
            if ($r =~ s/^([<>]=?)\s*//) {
                $range{$ops{$1}} = $self->_numify($r);
            } elsif ($r =~ s/\!=\s*//) {
                push @exclusion, $self->_numify($r);
            }
        }

        my @filters= (
            { range => { 'module.version_numified' => \%range } },
        );

        if (@exclusion) {
            push @filters, {
                not => { or => [ map { +{ term => { 'module.version_numified' => $self->_numify($_) } } } @exclusion ] },
            };
        }

        return @filters;
    }
}

# Apparently MetaCPAN numifies devel releases by stripping _ first
sub _numify {
    my($self, $ver) = @_;
    $ver =~ s/_//g;
    version->new($ver)->numify;
}

sub _maturity_filter {
    my($self, $module, $version) = @_;

    my @filters;

    if ($self->include_dev) {
        # backpan'ed dev release are considered "cancelled"
        push @filters, { not => { term => { status => 'backpan' } } };
    }

    my $explicit_version = $version && $version =~ /==/;

    unless ($self->include_dev or $explicit_version) {
        push @filters, { term => { maturity => 'released' } };
    }

    return @filters;
}

sub by_version {
    # version: higher version that satisfies the query
    $b->{fields}{module}[0]{"version_numified"} <=> $a->{fields}{module}[0]{"version_numified"};
}

sub by_status {
    # prefer non-backpan dist
    my %s = (latest => 3,  cpan => 2,  backpan => 1);
    $s{ $b->{fields}{status} } <=> $s{ $a->{fields}{status} };
}

sub by_date {
    # prefer new uploads
    $b->{fields}{date} cmp $a->{fields}{date};
}

sub _find_best_match {
    my($self, $match, $version) = @_;
    return unless $match && @{$match->{hits}{hits} || []};
    my @hits = sort { by_version || by_status || by_date } @{$match->{hits}{hits}};
    $hits[0]->{fields};
}

sub index_age { return time }    # pretend always current

sub search_authors { return }    # not supported

1;

=for Pod::Coverage attributes validate_attributes search_packages search_authors BUILD

=head1 SYNOPSIS

  use CPAN::Common::Index::MetaCPAN;

  $index = CPAN::Common::Index::MetaCPAN->new({ include_dev => 1 });
  $index->search_packages({ package => "Moose", version => "1.1" });
  $index->search_packages({ package => "Moose", version_range => ">= 1.1, < 2" });

=head1 DESCRIPTION

This module implements a CPAN::Common::Index that searches for packages against
the MetaCPAN API.

This backend supports searching modules with a version range (as
specified in L<CPAN::Meta::Spec>) which is translated into MetaCPAN
search query.

There is also a support for I<dev> release search, by passing
C<include_dev> parameter to the index object.

The result may include an optional field C<download_uri> which
suggests a specific mirror URL to download from, which can be
C<backpan.org> if the archive was deleted, or C<cpan.metacpan.org> if
the release date is within 1 day (because some mirrors might not have
synced it yet).

There is no support for searching packages with a regular expression, nor searching authors.

=cut

# vim: ts=4 sts=4 sw=4 et:
