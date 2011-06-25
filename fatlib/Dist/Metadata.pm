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

