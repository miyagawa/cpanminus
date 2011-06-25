# vim: set ts=2 sts=2 sw=2 expandtab smarttab:
#
# This file is part of Dist-Metadata
#
# This software is copyright (c) 2011 by Randy Stauner.
#
# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
#
use strict;
use warnings;

package Dist::Metadata;
BEGIN {
  $Dist::Metadata::VERSION = '0.904';
}
BEGIN {
  $Dist::Metadata::AUTHORITY = 'cpan:RWSTAUNER';
}
# ABSTRACT: Information about a perl module distribution

use Carp qw(croak carp);
use CPAN::Meta 2.1 ();
use List::Util qw(first);    # core in perl v5.7.3

# something that is obviously not a real value
use constant UNKNOWN => '- unknown -';


sub new {
  my $class = shift;
  my $self  = {
    determine_packages => 1,
    @_ == 1 ? %{ $_[0] } : @_
  };

  my @formats = qw( dist file dir struct );
  croak(qq[A dist must be specified (one of ] .
      join(', ', map { "'$_'" } @formats) . ')')
    unless first { $self->{$_} } @formats;

  bless $self, $class;
}


sub dist {
  my ($self) = @_;
  return $self->{dist} ||= do {
    my $dist;
    if( my $struct = $self->{struct} ){
      require Dist::Metadata::Struct;
      $dist = Dist::Metadata::Struct->new(%$struct);
    }
    elsif( my $dir = $self->{dir} ){
      require Dist::Metadata::Dir;
      $dist = Dist::Metadata::Dir->new(dir => $dir);
    }
    elsif ( my $file = $self->{file} ){
      require Dist::Metadata::Tar;
      $dist = Dist::Metadata::Tar->new(file => $file);
    }
    $dist; # return
  };
}


sub default_metadata {
  my ($self) = @_;

  return {
    # required
    abstract       => UNKNOWN,
    author         => [],
    dynamic_config => 0,
    generated_by   => ( ref($self) || $self ) . ' version ' . $self->VERSION,
    license        => ['unknown'], # this 'unknown' comes from CPAN::Meta::Spec
    'meta-spec'    => {
      version => '2',
      url     => 'http://search.cpan.org/perldoc?CPAN::Meta::Spec',
    },
    name           => UNKNOWN,
    release_status => 'stable',
    version        => 0,

    # optional
    no_index => {
      # ignore test and build directories by default
      directory => [qw( inc t xt )],
    },
    # provides => { package => { file => $file, version => $version } }
  };
}


sub determine_metadata {
  my ($self) = @_;

  my $dist = $self->dist;
  my $meta = $self->default_metadata;

  # get name and version from dist if dist was able to parse them
  foreach my $att (qw(name version)) {
    my $val = $dist->$att;
    # if the dist could determine it that's better than the default
    # but undef won't validate.  value in $self will still override.
    $meta->{$att} = $val
      if defined $val;
  }

  # any passed in values should take priority
  foreach my $field ( keys %$meta ){
    $meta->{$field} = $self->{$field}
      if exists $self->{$field};
  }

  return $meta;
}


sub determine_packages {
  # meta must be passed because to avoid infinite loop
  my ( $self, $meta ) = @_;
  # if not passed in, use defaults (we just want the 'no_index' property)
  $meta ||= $self->meta_from_struct( $self->determine_metadata );

  my @files = grep { $meta->should_index_file( $_ ) } $self->dist->perl_files;

  # TODO: should we limit packages to lib/ if it exists?
  # my @lib = grep { m#^lib/# } @files; @files = @lib if @lib;

  unless (@files) {
    warn("No perl files found in distribution\n");
    return {};
  }

  my $packages = $self->dist->determine_packages(@files);

  # remove any packages that should not be indexed (if any)
  foreach my $pack ( keys %$packages ) {
    delete $packages->{$pack}
      if !$meta->should_index_package($pack);
  }

  return $packages;
}


sub load_meta {
  my ($self) = @_;

  my $dist  = $self->dist;
  my @files = $dist->list_files;
  my ( $meta, $metafile );

  # prefer json file (spec v2)
  if ( $metafile = first { m#^META\.json$# } @files ) {
    $meta = CPAN::Meta->load_json_string( $dist->file_content($metafile) );
  }
  # fall back to yaml file (spec v1)
  elsif ( $metafile = first { m#^META\.ya?ml$# } @files ) {
    $meta = CPAN::Meta->load_yaml_string( $dist->file_content($metafile) );
  }
  # no META file found in dist
  else {
    $meta = $self->meta_from_struct( $self->determine_metadata );
  }

  # Something has to be indexed, so if META has no (or empty) 'provides'
  # attempt to determine packages unless specifically configured not to
  if ( !keys %{ $meta->provides || {} } && $self->{determine_packages} ) {
    # respect api/encapsulation
    my $struct = $meta->as_struct;
    $struct->{provides} = $self->determine_packages($meta);
    $meta = $self->meta_from_struct($struct);
  }

  return $meta;
}


sub meta {
  my ($self) = @_;
  return $self->{meta} ||= $self->load_meta;
}


sub meta_from_struct {
  my ($self, $struct) = @_;
  return CPAN::Meta->create( $struct, { lazy_validation => 1 } );
}


sub package_versions {
  my ($self) = shift;
  my $provides = @_ ? shift : $self->provides; # || {}
  return {
    map { ($_ => $provides->{$_}{version}) } keys %$provides
  };
}


{
  no strict 'refs'; ## no critic (NoStrict)
  foreach my $method ( qw(
    name
    provides
    version
  ) ){
    *$method = sub { $_[0]->meta->$method };
  }
}

1;


__END__
=pod

=for :stopwords Randy Stauner TODO dist dists dir unix cpan testmatrix url annocpan anno
bugtracker rt cpants kwalitee diff irc mailto metadata placeholders

=head1 NAME

Dist::Metadata - Information about a perl module distribution

=head1 VERSION

version 0.904

=head1 SYNOPSIS

  my $dist = Dist::Metadata->new(file => $path_to_archive);

  my $description = sprintf "Dist %s (%s)", $dist->name, $dist->version;

  my $provides = $dist->package_versions;
  while( my ($package, $version) = each %$provides ){
    print "$description includes $package $version\n";
  }

=head1 DESCRIPTION

This is sort of a companion to L<Module::Metadata>.
It provides an interface for getting information about a distribution.

This is mostly a wrapper around L<CPAN::Meta> providing an easy interface
to find and load the meta file from a F<tar.gz> file.
A dist can also be represented by a directory or merely a structure of data.

If the dist does not contain a meta file
the module will attempt to determine some of that data from the dist.

The current actions of this module are inspired by
what I believe the current PAUSE indexer does.

B<NOTE>: This interface is still being defined.
Please submit any suggestions or concerns.

=head1 METHODS

=head2 new

  Dist::Metadata->new(file => $path);

A dist can be represented by
a tar file,
a directory,
or a data structure.

The format will be determined by the presence of the following options
(checked in this order):

=over 4

=item *

C<struct> - hash of data to build a mock dist; See L<Dist::Metadata::Struct>.

=item *

C<dir> - path to the root directory of a dist

=item *

C<file> - the path to a F<.tar.gz> file

=back

You can also slyly pass in your own object as a C<dist> parameter
in which case this module will just use that.
This can be useful if you need to use your own subclass
(perhaps while developing a new format).

Other options that can be specified:

=over 4

=item *

C<name> - dist name

=item *

C<version> - dist version

=item *

C<determine_packages> - boolean to indicate whether dist should be searched
for packages if no META file is found.  Defaults to true.

=back

=head2 dist

Returns the dist object (subclass of L<Dist::Metadata::Dist>).

=head2 default_metadata

Returns a hashref of default values
used to initialize a L<CPAN::Meta> object
when a META file is not found.
Called from L</determine_metadata>.

=head2 determine_metadata

Examine the dist and try to determine metadata.
Returns a hashref which can be passed to L<CPAN::Meta/new>.
This is used when the dist does not contain a META file.

=head2 determine_packages

  my $provides = $dm->determine_packages($meta);

Attempt to determine packages provided by the dist.
This is used when the META file does not include a C<provides>
section and C<determine_packages> is not set to false in the constructor.

If a L<CPAN::Meta> object is not provided a default one will be used.
Files contained in the dist and packages found therein will be checked against
the meta object's C<no_index> attribute
(see L<CPAN::Meta/should_index_file>
and  L<CPAN::Meta/should_index_package>).
By default this ignores any files found in
F<inc/>,
F<t/>,
or F<xt/>
directories.

=head2 load_meta

Loads the metadata from the L</dist>.

=head2 meta

Returns the L<CPAN::Meta> instance in use.

=head2 meta_from_struct

  $meta = $dm->meta_from_struct(\%struct);

Passes the the provided C<\%struct> to L<CPAN::Meta/create>
and returns the result.

=head2 package_versions

  $pv = $dm->package_versions();
  # { 'Package::Name' => '1.0', 'Module::2' => '2.1' }

Returns a simplified version of C<provides>:
a hashref with package names as keys and versions as values.

This can also be called as a class method
which will operate on a passed in hashref.

  $pv = Dist::Metadata->package_versions(\%provides);

=head1 INHERITED METHODS

The following methods are available on this object
and simply call the corresponding method on the L<CPAN::Meta> object.

=over 4

=item *

X<name> name

=item *

X<provides> provides

=item *

X<version> version

=back

=for Pod::Coverage name version provides

=for test_synopsis my $path_to_archive;

=head1 TODO

=over 4

=item *

More tests

=item *

C<trust_meta> option (to allow setting it to false)

=item *

Guess main module from dist name if no packages can be found

=item *

Determine abstract?

=item *

Review code to ensure proper, consistent use of L<File::Spec>

=item *

Use L<CPAN::DistnameInfo> to parse name/version from files

=item *

Add change log info (L<CPAN::Changes>)?

=item *

Subclass as C<CPAN::Dist::Metadata> just so that it has C<CPAN> in the name?

=back

=head1 SEE ALSO

=head2 Dependencies

=over 4

=item *

L<Module::Metadata>

=item *

L<CPAN::Meta>

=back

=head2 Related Modules

=over 4

=item *

L<MyCPAN::Indexer>

=item *

L<CPAN::ParseDistribution>

=back

=head1 SUPPORT

=head2 Perldoc

You can find documentation for this module with the perldoc command.

  perldoc Dist::Metadata

=head2 Websites

The following websites have more information about this module, and may be of help to you. As always,
in addition to those websites please use your favorite search engine to discover more resources.

=over 4

=item *

Search CPAN

The default CPAN search engine, useful to view POD in HTML format.

L<http://search.cpan.org/dist/Dist-Metadata>

=item *

RT: CPAN's Bug Tracker

The RT ( Request Tracker ) website is the default bug/issue tracking system for CPAN.

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Dist-Metadata>

=item *

CPAN Ratings

The CPAN Ratings is a website that allows community ratings and reviews of Perl modules.

L<http://cpanratings.perl.org/d/Dist-Metadata>

=item *

CPAN Testers

The CPAN Testers is a network of smokers who run automated tests on uploaded CPAN distributions.

L<http://www.cpantesters.org/distro/D/Dist-Metadata>

=item *

CPAN Testers Matrix

The CPAN Testers Matrix is a website that provides a visual overview of the test results for a distribution on various Perls/platforms.

L<http://matrix.cpantesters.org/?dist=Dist-Metadata>

=item *

CPAN Testers Dependencies

The CPAN Testers Dependencies is a website that shows a chart of the test results of all dependencies for a distribution.

L<http://deps.cpantesters.org/?module=Dist::Metadata>

=back

=head2 Bugs / Feature Requests

Please report any bugs or feature requests by email to C<bug-dist-metadata at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Dist-Metadata>. You will be automatically notified of any
progress on the request by the system.

=head2 Source Code


L<http://github.com/magnificent-tears/Dist-Metadata>

  git clone http://github.com/magnificent-tears/Dist-Metadata

=head1 AUTHOR

Randy Stauner <rwstauner@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Randy Stauner.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

