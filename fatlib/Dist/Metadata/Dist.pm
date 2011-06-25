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

