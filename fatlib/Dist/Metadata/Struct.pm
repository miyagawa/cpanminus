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

package Dist::Metadata::Struct;
BEGIN {
  $Dist::Metadata::Struct::VERSION = '0.904';
}
BEGIN {
  $Dist::Metadata::Struct::AUTHORITY = 'cpan:RWSTAUNER';
}
# ABSTRACT: Enable Dist::Metadata for a data structure

use Carp qw(croak carp); # core
use File::Spec::Unix (); # core
use parent 'Dist::Metadata::Dist';

push(@Dist::Metadata::CARP_NOT, __PACKAGE__);


sub required_attribute { 'files' }


sub default_file_spec { 'File::Spec::Unix' }


sub file_content {
  my ($self, $file) = @_;
  my $content = $self->{files}{ $self->full_path($file) };

  # 5.10: given(ref($content))

  if( my $ref = ref $content ){
    return $ref eq 'SCALAR'
      # allow a scalar ref
      ? $$content
      # or an IO-like object
      : do { local $/; $content->getline; }
  }
  # else a simple string
  return $content;
}


sub find_files {
  my ($self) = @_;

  # place an entry in the hash for consistency with other formats
  $self->{dir} = '';

  return keys %{ $self->{files} };
}

1;


__END__
=pod

