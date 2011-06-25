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

package Dist::Metadata::Dist;
BEGIN {
  $Dist::Metadata::Dist::VERSION = '0.904';
}
BEGIN {
  $Dist::Metadata::Dist::AUTHORITY = 'cpan:RWSTAUNER';
}
# ABSTRACT: Base class for format-specific implementations

use Carp qw(croak carp);     # core
use File::Spec ();           # core
use File::Spec::Unix ();     # core
use Try::Tiny 0.09;


sub new {
  my $class = shift;
  my $self  = {
    @_ == 1 ? %{ $_[0] } : @_
  };

  bless $self, $class;

  my $req = $class->required_attribute;
  croak qq['$req' parameter required]
    if $req && !$self->{$req};

  return $self;
}


sub default_file_spec { 'File::Spec' }


sub determine_name_and_version {
  my ($self) = @_;
  $self->set_name_and_version( $self->parse_name_and_version( $self->root ) );
  return;
}


sub determine_packages {
  my ($self, @files) = @_;

  my $determined = try {
    my $dir = $self->physical_directory(@files);

    # return
    $self->packages_from_directory($dir, @files);
  }
  catch {
    carp("Error determining packages: $_[0]");
    +{}; # return
  };

  return $determined;
}


sub extract_into {
  my ($self, $dir, @files) = @_;

  @files = $self->list_files
    unless @files;

  require File::Path;
  require File::Basename;

  foreach my $file (@files) {
    my $path = File::Spec->catfile($dir, $file);

    # legacy interface (should be compatible with whatever version is installed)
    File::Path::mkpath( File::Basename::dirname($path), 0, oct(700) );

    open(my $fh, '>', $path)
      or croak "Failed to open '$path' for writing: $!";
    print $fh $self->file_content($file);
  }

  return $dir;
}


sub file_content {
  croak q[Method 'file_content' not defined];
}


sub find_files {
  croak q[Method 'find_files' not defined];
}


sub file_spec {
  return $_[0]->{file_spec} ||= $_[0]->default_file_spec;
}


sub full_path {
  my ($self, $file) = @_;

  return $file
    unless my $root = $self->root;

  # don't re-add the root if it's already there
  return $file
    # FIXME: this regexp is probably not cross-platform...
    # FIXME: is there a way to do this with File::Spec?
    if $file =~ m@^\Q${root}\E[\\/]@;

  return $self->file_spec->catfile($root, $file);
}


sub list_files {
  my ($self) = @_;

  $self->{_list_files} = do {
    my @files = sort $self->find_files;
    my ($root, @rel) = $self->remove_root_dir(@files);
    $self->{root} = $root;
    \@rel; # return
  }
    unless $self->{_list_files};

  return @{ $self->{_list_files} };
}


{
  no strict 'refs'; ## no critic (NoStrict)
  foreach my $method ( qw(
    name
    version
  ) ){
    *$method = sub {
      my ($self) = @_;

      $self->determine_name_and_version
        if !exists $self->{ $method };

      return $self->{ $method };
    };
  }
}


sub packages_from_directory {
  my ($self, $dir, @files) = @_;

  require Module::Metadata;

  my $provides = try {
    # M::M::p_v_f_d expects full paths for \@files
    my $packages = Module::Metadata->package_versions_from_directory($dir,
      # FIXME: $self->file_spec->splitpath($_) (write tests first)
      [map { File::Spec->catfile($dir, $_) } @files]
    );
    while ( my ($pack, $pv) = each %$packages ) {
      # CPAN::Meta expects file paths in Unix format
      # since M::M::p_v_f_d reads from physical dir use base File::Spec to split
      $pv->{file} =
        File::Spec::Unix->catfile( File::Spec->splitdir( $pv->{file} ) );
    }
    $packages; # return
  }
  catch {
    carp("Failed to determine packages: $_[0]");
    +{}; # return
  };
  return $provides || {};
}


sub parse_name_and_version {
  my ($self, $path) = @_;
  my ( $name, $version );
  if ( $path ){
    $path =~ m!
      ([^\\/]+)             # name (anything below final directory)
      -                     # separator
      (v?[0-9._]+)          # version
      (?:                   # possible file extensions
          \.t(?:ar\.)?gz
      )?
      $
    !x and
      ( $name, $version ) = ( $1, $2 );
  }
  return ($name, $version);
}



sub perl_files {
  return
    grep { /\.pm$/ }
    $_[0]->list_files;
}


sub physical_directory {
  my ($self, @files) = @_;

  require   File::Temp;
  # dir will be removed when return value goes out of scope (in caller)
  my $dir = File::Temp->newdir();

  $self->extract_into($dir, @files);
  return $dir;
}


sub remove_root_dir {
  my ($self, @files) = @_;
  return unless @files;

  # FIXME: can we use File::Spec for these regexp's instead of [\\/] ?

  # grab the root dir from the first file
  $files[0] =~ m{^([^\\/]+)[\\/]}
    # if not matched quit now
    or return (undef, @files);

  my $dir = $1;
  my @rel;

  # strip $dir from each file
  for (@files) {

    m{^\Q$dir\E[\\/](.+)$}
      # if the match failed they're not all under the same root so just return now
      or return (undef, @files);

    push @rel, $1;
  }

  return ($dir, @rel);

}


sub required_attribute { return }


sub root {
  my ($self) = @_;

  # call list_files instead of find_files so that it caches the result
  $self->list_files
    unless exists $self->{root};

  return $self->{root};
}


sub set_name_and_version {
  my ($self, @values) = @_;
  my @fields = qw( name version );

  foreach my $i ( 0 .. $#fields ){
    $self->{ $fields[$i] } = $values[$i]
      if !exists $self->{ $fields[$i] } && defined $values[$i];
  }
  return;
}


# version() defined with name()

1;


__END__
=pod

=for :stopwords Randy Stauner TODO dist dists dir unix

=head1 NAME

Dist::Metadata::Dist - Base class for format-specific implementations

=head1 VERSION

version 0.904

=head1 SYNOPSIS

  # don't use this, use a subclass

=head1 DESCRIPTION

This is a base class for different dist formats.

The following methods B<must> be defined by subclasses:

=over 4

=item *

L</file_content>

=item *

L</find_files>

=back

=head1 METHODS

=head2 new

Simple constructor that subclasses can inherit.
Ensures the presence of L</required_attribute>
if defined by the subclass.

=head2 default_file_spec

Defaults to C<File::Spec> in the base class.
See L</file_spec>.

=head2 determine_name_and_version

Some dist formats may define a way to determine the name and version.

=head2 determine_packages

  $packages = $dist->determine_packages(@files);

Search the specified files (or all files if unspecified)
for perl packages.

Extracts the files to a temporary directory if necessary
and uses L<Module::Metadata> to discover package names and versions.

=head2 extract_into

  $dist->extract_into($dir, @files);

Extracts the specified files (or all files if not specified)
into the specified directory.

=head2 file_content

Returns the content for the specified file from the dist.
Must be defined by subclasses.

=head2 find_files

Determine the files contained in the dist.

This is called from L</list_files> and cached on the object.

=head2 file_spec

Returns the class name of the L<File::Spec> module used for this format.
This is mostly so subclasses can define a specific one if necessary.

A C<file_spec> attribute can be passed to the constructor
to override the default.
If you do this be sure to require the class you specify first
(this module does not attempt to load it).

B<NOTE>: This is used for the internal format of the dist.
Tar archives, for example, are always in unix format.
For operations outside of the dist, L<File::Spec> will always be used.

=head2 full_path

  $dist->full_path("lib/Mod.pm"); # "root-dir/lib/Mod.pm"

Used internally to put the L</root> directory back onto the file.

=head2 list_files

Returns a list of the files in the dist starting at the dist root.

This calls L</find_files> to get a listing of the contents of the dist,
determines (and caches) the root directory (if any),
caches and returns the the list of files with the root dir stripped.

  @files = $dist->list_files;
  # something like qw( README META.yml lib/Mod.pm )

=head2 name

The dist name if it could be determined.

=head2 packages_from_directory

  $provides = $dist->packages_from_directory($dir, @files);

Determines the packages provided by the perl modules found in a directory.
This is thin wrapper around
L<Module::Metadata/package_versions_from_directory>.
It returns a hashref like L<CPAN::Meta::Spec/provides>.

=head2 parse_name_and_version

  ($name, $version) = $dist->parse_name_and_version($path);

Attempt to parse name and version from the provided string.
This will work for dists named like "Dist-Name-1.0".

=head2 perl_files

Returns the subset of L</list_files> that look like perl files.
Currently returns anything matching C</\.pm$/>

B<TODO>: This should probably be customizable.

=head2 physical_directory

Returns the path to a physical directory on the disk
where the specified files can be found.

For in-memory formats this will make a temporary directory
and write the specified files (or all files) into it.

=head2 remove_root_dir

  my ($dir, @rel) = $dm->remove_root_dir(@files);

If all the C<@files> are beneath the same root directory
(as is normally the case) this will strip the root directory off of each file
and return a list of the root directory and the stripped files.

If there is no root directory the first element of the list will be C<undef>.

=head2 required_attribute

A single attribute that is required by the class.
Subclasses can define this to make L</new> C<croak> if it isn't present.

=head2 root

Returns the root directory of the dist (if there is one).

=head2 set_name_and_version

This is a convenience method for setting the name and version
if they haven't already been set.
This is often called by L</determine_name_and_version>.

=head2 version

Returns the version if it could be determined from the dist.

=head1 SEE ALSO

=over 4

=item *

L<Dist::Metadata::Tar> - for examining a tar file

=item *

L<Dist::Metadata::Dir> - for a directory already on the disk

=item *

L<Dist::Metadata::Struct> - for mocking up a dist with perl data structures

=back

=head1 AUTHOR

Randy Stauner <rwstauner@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Randy Stauner.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

