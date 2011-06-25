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

package Dist::Metadata::Dir;
BEGIN {
  $Dist::Metadata::Dir::VERSION = '0.904';
}
BEGIN {
  $Dist::Metadata::Dir::AUTHORITY = 'cpan:RWSTAUNER';
}
# ABSTRACT: Enable Dist::Metadata for a directory

use Carp qw(croak carp);    # core
use File::Find ();          # core
use File::Spec ();          # core
use parent 'Dist::Metadata::Dist';

push(@Dist::Metadata::CARP_NOT, __PACKAGE__);


sub new {
  my $class = shift;
  my $self = $class->SUPER::new(@_);

  # chop trailing slash if present
  $self->{dir} =~ s{/*$}{};

  return $self;
}

sub required_attribute { 'dir' }


sub determine_name_and_version {
  my ($self) = @_;
  $self->set_name_and_version( $self->parse_name_and_version( $self->dir ) );
  return $self->SUPER::determine_name_and_version();
}


sub dir {
  $_[0]->{dir};
}

# this shouldn't be called
sub extract_into {
  croak q[A directory doesn't need to be extracted];
}


sub file_content {
  my ($self, $file) = @_;
  my $path = File::Spec->catfile($self->{dir}, $self->full_path($file));

  open(my $fh, '<', $path)
    or croak "Failed to open file '$path': $!";

  return do { local $/; <$fh> };
}


sub find_files {
  my ($self) = @_;

  my $dir = $self->{dir};
  my @files;

  File::Find::find(
    {
      wanted => sub {
        push @files, File::Spec->abs2rel($_, $dir)
          if -f $_;
      },
      no_chdir => 1
    },
    $dir
  );

  return @files;
}


sub physical_directory {
  my ($self) = @_;

  # go into root dir if there is one
  return File::Spec->catdir($self->{dir}, $self->{root})
    if $self->{root};

  return $self->{dir};
}

1;


__END__
=pod

