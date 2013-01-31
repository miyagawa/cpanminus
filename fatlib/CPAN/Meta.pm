use 5.006;
use strict;
use warnings;
package CPAN::Meta;
our $VERSION = '2.120921'; # VERSION


use Carp qw(carp croak);
use CPAN::Meta::Feature;
use CPAN::Meta::Prereqs;
use CPAN::Meta::Converter;
use CPAN::Meta::Validator;
use Parse::CPAN::Meta 1.4403 ();

BEGIN { *_dclone = \&CPAN::Meta::Converter::_dclone }


BEGIN {
  my @STRING_READERS = qw(
    abstract
    description
    dynamic_config
    generated_by
    name
    release_status
    version
  );

  no strict 'refs';
  for my $attr (@STRING_READERS) {
    *$attr = sub { $_[0]{ $attr } };
  }
}


BEGIN {
  my @LIST_READERS = qw(
    author
    keywords
    license
  );

  no strict 'refs';
  for my $attr (@LIST_READERS) {
    *$attr = sub {
      my $value = $_[0]{ $attr };
      croak "$attr must be called in list context"
        unless wantarray;
      return @{ _dclone($value) } if ref $value;
      return $value;
    };
  }
}

sub authors  { $_[0]->author }
sub licenses { $_[0]->license }


BEGIN {
  my @MAP_READERS = qw(
    meta-spec
    resources
    provides
    no_index

    prereqs
    optional_features
  );

  no strict 'refs';
  for my $attr (@MAP_READERS) {
    (my $subname = $attr) =~ s/-/_/;
    *$subname = sub {
      my $value = $_[0]{ $attr };
      return _dclone($value) if $value;
      return {};
    };
  }
}


sub custom_keys {
  return grep { /^x_/i } keys %{$_[0]};
}

sub custom {
  my ($self, $attr) = @_;
  my $value = $self->{$attr};
  return _dclone($value) if ref $value;
  return $value;
}


sub _new {
  my ($class, $struct, $options) = @_;
  my $self;

  if ( $options->{lazy_validation} ) {
    # try to convert to a valid structure; if succeeds, then return it
    my $cmc = CPAN::Meta::Converter->new( $struct );
    $self = $cmc->convert( version => 2 ); # valid or dies
    return bless $self, $class;
  }
  else {
    # validate original struct
    my $cmv = CPAN::Meta::Validator->new( $struct );
    unless ( $cmv->is_valid) {
      die "Invalid metadata structure. Errors: "
        . join(", ", $cmv->errors) . "\n";
    }
  }

  # up-convert older spec versions
  my $version = $struct->{'meta-spec'}{version} || '1.0';
  if ( $version == 2 ) {
    $self = $struct;
  }
  else {
    my $cmc = CPAN::Meta::Converter->new( $struct );
    $self = $cmc->convert( version => 2 );
  }

  return bless $self, $class;
}

sub new {
  my ($class, $struct, $options) = @_;
  my $self = eval { $class->_new($struct, $options) };
  croak($@) if $@;
  return $self;
}


sub create {
  my ($class, $struct, $options) = @_;
  my $version = __PACKAGE__->VERSION || 2;
  $struct->{generated_by} ||= __PACKAGE__ . " version $version" ;
  $struct->{'meta-spec'}{version} ||= int($version);
  my $self = eval { $class->_new($struct, $options) };
  croak ($@) if $@;
  return $self;
}


sub load_file {
  my ($class, $file, $options) = @_;
  $options->{lazy_validation} = 1 unless exists $options->{lazy_validation};

  croak "load_file() requires a valid, readable filename"
    unless -r $file;

  my $self;
  eval {
    my $struct = Parse::CPAN::Meta->load_file( $file );
    $self = $class->_new($struct, $options);
  };
  croak($@) if $@;
  return $self;
}


sub load_yaml_string {
  my ($class, $yaml, $options) = @_;
  $options->{lazy_validation} = 1 unless exists $options->{lazy_validation};

  my $self;
  eval {
    my ($struct) = Parse::CPAN::Meta->load_yaml_string( $yaml );
    $self = $class->_new($struct, $options);
  };
  croak($@) if $@;
  return $self;
}


sub load_json_string {
  my ($class, $json, $options) = @_;
  $options->{lazy_validation} = 1 unless exists $options->{lazy_validation};

  my $self;
  eval {
    my $struct = Parse::CPAN::Meta->load_json_string( $json );
    $self = $class->_new($struct, $options);
  };
  croak($@) if $@;
  return $self;
}


sub save {
  my ($self, $file, $options) = @_;

  my $version = $options->{version} || '2';
  my $layer = $] ge '5.008001' ? ':utf8' : '';

  if ( $version ge '2' ) {
    carp "'$file' should end in '.json'"
      unless $file =~ m{\.json$};
  }
  else {
    carp "'$file' should end in '.yml'"
      unless $file =~ m{\.yml$};
  }

  my $data = $self->as_string( $options );
  open my $fh, ">$layer", $file
    or die "Error opening '$file' for writing: $!\n";

  print {$fh} $data;
  close $fh
    or die "Error closing '$file': $!\n";

  return 1;
}


sub meta_spec_version {
  my ($self) = @_;
  return $self->meta_spec->{version};
}


sub effective_prereqs {
  my ($self, $features) = @_;
  $features ||= [];

  my $prereq = CPAN::Meta::Prereqs->new($self->prereqs);

  return $prereq unless @$features;

  my @other = map {; $self->feature($_)->prereqs } @$features;

  return $prereq->with_merged_prereqs(\@other);
}


sub should_index_file {
  my ($self, $filename) = @_;

  for my $no_index_file (@{ $self->no_index->{file} || [] }) {
    return if $filename eq $no_index_file;
  }

  for my $no_index_dir (@{ $self->no_index->{directory} }) {
    $no_index_dir =~ s{$}{/} unless $no_index_dir =~ m{/\z};
    return if index($filename, $no_index_dir) == 0;
  }

  return 1;
}


sub should_index_package {
  my ($self, $package) = @_;

  for my $no_index_pkg (@{ $self->no_index->{package} || [] }) {
    return if $package eq $no_index_pkg;
  }

  for my $no_index_ns (@{ $self->no_index->{namespace} }) {
    return if index($package, "${no_index_ns}::") == 0;
  }

  return 1;
}


sub features {
  my ($self) = @_;

  my $opt_f = $self->optional_features;
  my @features = map {; CPAN::Meta::Feature->new($_ => $opt_f->{ $_ }) }
                 keys %$opt_f;

  return @features;
}


sub feature {
  my ($self, $ident) = @_;

  croak "no feature named $ident"
    unless my $f = $self->optional_features->{ $ident };

  return CPAN::Meta::Feature->new($ident, $f);
}


sub as_struct {
  my ($self, $options) = @_;
  my $struct = _dclone($self);
  if ( $options->{version} ) {
    my $cmc = CPAN::Meta::Converter->new( $struct );
    $struct = $cmc->convert( version => $options->{version} );
  }
  return $struct;
}


sub as_string {
  my ($self, $options) = @_;

  my $version = $options->{version} || '2';

  my $struct;
  if ( $self->meta_spec_version ne $version ) {
    my $cmc = CPAN::Meta::Converter->new( $self->as_struct );
    $struct = $cmc->convert( version => $version );
  }
  else {
    $struct = $self->as_struct;
  }

  my ($data, $backend);
  if ( $version ge '2' ) {
    $backend = Parse::CPAN::Meta->json_backend();
    $data = $backend->new->pretty->canonical->encode($struct);
  }
  else {
    $backend = Parse::CPAN::Meta->yaml_backend();
    $data = eval { no strict 'refs'; &{"$backend\::Dump"}($struct) };
    if ( $@ ) {
      croak $backend->can('errstr') ? $backend->errstr : $@
    }
  }

  return $data;
}

# Used by JSON::PP, etc. for "convert_blessed"
sub TO_JSON {
  return { %{ $_[0] } };
}

1;

# ABSTRACT: the distribution metadata for a CPAN dist




__END__


