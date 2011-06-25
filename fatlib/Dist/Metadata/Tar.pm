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

package Dist::Metadata::Tar;
BEGIN {
  $Dist::Metadata::Tar::VERSION = '0.904';
}
BEGIN {
  $Dist::Metadata::Tar::AUTHORITY = 'cpan:RWSTAUNER';
}
# ABSTRACT: Enable Dist::Metadata for tar files

use Archive::Tar ();
use Carp qw(croak carp); # core
use File::Spec::Unix (); # core
use Try::Tiny 0.09;
use parent 'Dist::Metadata::Dist';

push(@Dist::Metadata::CARP_NOT, __PACKAGE__);


sub required_attribute { 'file' }


sub default_file_spec { 'File::Spec::Unix' }


sub determine_name_and_version {
  my ($self) = @_;
  $self->set_name_and_version( $self->parse_name_and_version( $self->file ) );
  return $self->SUPER::determine_name_and_version(@_);
}


sub file {
  return $_[0]->{file};
}


sub file_content {
  my ( $self, $file ) = @_;
  return $self->tar->get_content( $self->full_path($file) );
}


sub find_files {
  my ($self) = @_;
  return
    map  { $_->full_path }
    grep { $_->is_file   }
      $self->tar->get_files;
}


sub tar {
  my ($self) = @_;
  return $self->{tar} ||= do {
    my $file = $self->file;

    croak "File '$file' does not exist"
      unless -e $file;

    my $tar = Archive::Tar->new();
    $tar->read($file);

    $tar; # return
  };
}

1;


__END__
=pod

