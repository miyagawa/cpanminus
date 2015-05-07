package Menlo::HTTP::Tinyish::Wget;
use strict;
use warnings;
use IPC::Run3 qw(run3);
use File::Which qw(which);
use Menlo::HTTP::Tinyish::Util qw(parse_http_response internal_error);

my %supports;
my $wget;

sub configure {
    my $class = shift;

    $wget = which('wget');

    eval {
        local $ENV{LC_ALL} = 'en_US';

        my $config = $class->new(agent => __PACKAGE__);
        my @options = grep { $_ ne '--quiet' } $config->build_options;

        run3([$wget, @options, 'https://'], \undef, \my $out, \my $err);

        if ($err && $err =~ /HTTPS support not compiled/) {
            $supports{http} = 1;
        } elsif ($err && $err =~ /Invalid host/) {
            $supports{http} = $supports{https} = 1;
        }
    };
}

sub supports { $supports{$_[1]} }

sub new {
    my($class, %attr) = @_;
    bless \%attr, $class;
}

sub get {
    my($self, $url) = @_;

    my($stdout, $stderr);
    eval {
        run3 [$wget, $self->build_options($url), $url, '-O', '-'], \undef, \$stdout, \$stderr;
    };

    if ($? && $? <= 128) {
        return internal_error($url, $@ || $stderr);
    }

    $stderr =~ s/^  //gm;
    $stderr =~ s/.+^(HTTP\/\d\.\d)/$1/ms; # multiple replies for authenticated requests :/

    my $res = { url => $url };
    parse_http_response(join("\n", $stderr, $stdout), $res);
    $res;
}

sub mirror {
    my($self, $url, $file) = @_;

    # This doesn't send If-Modified-Since because -O and -N are mutually exclusive :(
    my($stdout, $stderr);
    eval {
        run3 [$wget, $self->build_options($url), $url, '-O', $file], \undef, \$stdout, \$stderr;
    };

    if ($@ or $?) {
        return internal_error($url, $@ || $stderr);
    }

    $stderr =~ s/^  //gm;
    $stderr =~ s/.*^(HTTP\/\d\.\d)/$1/ms; # multiple replies for authenticated requests :/

    my $res = { url => $url };
    parse_http_response(join("\n", $stderr, $stdout), $res);
    $res;
}

sub build_options {
    my($self, $url) = @_;

    my @options = (
        '--retry-connrefused',
        '--quiet',
        '--server-response',
    );

    if ($self->{agent}) {
        push @options,
          '--user-agent', $self->{agent};
    }

    @options;
}

1;
