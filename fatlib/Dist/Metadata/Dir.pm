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

=for :stopwords Randy Stauner TODO dist dists dir unix

=head1 NAME

Dist::Metadata::Dir - Enable Dist::Metadata for a directory

=head1 VERSION

version 0.904

=head1 SYNOPSIS

  my $dm = Dist::Metadata->new(dir => $path_to_dir);

=head1 DESCRIPTION

This is a subclass of L<Dist::Metadata::Dist>
to enable getting the dists metadata from a directory.

This can be useful if you already have a dist extracted into a directory.

It's probably not very useful on it's own though,
and should be used from L<Dist::Metadata/new>.

=head1 METHODS

=head2 new

  $dist = Dist::Metadata::Struct->new(dir => $path);

Accepts a single 'dir' argument that should be a path to a directory.

=head2 determine_name_and_version

Attempts to parse name and version from directory name.

=head2 dir

Returns the C<dir> attribute specified in the constructor.

=head2 file_content

Returns the content for the specified file.

=head2 find_files

Returns a list of the file names beneath the directory
(relative to the directory).

=head2 physical_directory

Returns the C<dir> attribute since this is already a directory
containing the desired files.

=for test_synopsis my $path_to_dir;

=head1 AUTHOR

Randy Stauner <rwstauner@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Randy Stauner.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

