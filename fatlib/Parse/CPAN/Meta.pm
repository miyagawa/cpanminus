package Parse::CPAN::Meta;

use strict;
use Carp 'croak';

# UTF Support?
sub HAVE_UTF8 () { $] >= 5.007003 }
sub IO_LAYER () { $] >= 5.008001 ? ":utf8" : "" }  

BEGIN {
	if ( HAVE_UTF8 ) {
		# The string eval helps hide this from Test::MinimumVersion
		eval "require utf8;";
		die "Failed to load UTF-8 support" if $@;
	}

	# Class structure
	require 5.004;
	require Exporter;
	$Parse::CPAN::Meta::VERSION   = '1.4404';
	@Parse::CPAN::Meta::ISA       = qw{ Exporter      };
	@Parse::CPAN::Meta::EXPORT_OK = qw{ Load LoadFile };
}

sub load_file {
  my ($class, $filename) = @_;

  if ($filename =~ /\.ya?ml$/) {
    return $class->load_yaml_string(_slurp($filename));
  }

  if ($filename =~ /\.json$/) {
    return $class->load_json_string(_slurp($filename));
  }

  croak("file type cannot be determined by filename");
}

sub load_yaml_string {
  my ($class, $string) = @_;
  my $backend = $class->yaml_backend();
  my $data = eval { no strict 'refs'; &{"$backend\::Load"}($string) };
  if ( $@ ) { 
    croak $backend->can('errstr') ? $backend->errstr : $@
  }
  return $data || {}; # in case document was valid but empty
}

sub load_json_string {
  my ($class, $string) = @_;
  return $class->json_backend()->new->decode($string);
}

sub yaml_backend {
  local $Module::Load::Conditional::CHECK_INC_HASH = 1;
  if (! defined $ENV{PERL_YAML_BACKEND} ) {
    _can_load( 'CPAN::Meta::YAML', 0.002 )
      or croak "CPAN::Meta::YAML 0.002 is not available\n";
    return "CPAN::Meta::YAML";
  }
  else {
    my $backend = $ENV{PERL_YAML_BACKEND};
    _can_load( $backend )
      or croak "Could not load PERL_YAML_BACKEND '$backend'\n";
    $backend->can("Load")
      or croak "PERL_YAML_BACKEND '$backend' does not implement Load()\n";
    return $backend;
  }
}

sub json_backend {
  local $Module::Load::Conditional::CHECK_INC_HASH = 1;
  if (! $ENV{PERL_JSON_BACKEND} or $ENV{PERL_JSON_BACKEND} eq 'JSON::PP') {
    _can_load( 'JSON::PP' => 2.27103 )
      or croak "JSON::PP 2.27103 is not available\n";
    return 'JSON::PP';
  }
  else {
    _can_load( 'JSON' => 2.5 )
      or croak  "JSON 2.5 is required for " .
                "\$ENV{PERL_JSON_BACKEND} = '$ENV{PERL_JSON_BACKEND}'\n";
    return "JSON";
  }
}

sub _slurp {
  open my $fh, "<" . IO_LAYER, "$_[0]"
    or die "can't open $_[0] for reading: $!";
  return do { local $/; <$fh> };
}
  
sub _can_load {
  my ($module, $version) = @_;
  (my $file = $module) =~ s{::}{/}g;
  $file .= ".pm";
  return 1 if $INC{$file};
  return 0 if exists $INC{$file}; # prior load failed
  eval { require $file; 1 }
    or return 0;
  if ( defined $version ) {
    eval { $module->VERSION($version); 1 }
      or return 0;
  }
  return 1;
}

# Kept for backwards compatibility only
# Create an object from a file
sub LoadFile ($) {
  require CPAN::Meta::YAML;
  return CPAN::Meta::YAML::LoadFile(shift)
    or die CPAN::Meta::YAML->errstr;
}

# Parse a document from a string.
sub Load ($) {
  require CPAN::Meta::YAML;
  return CPAN::Meta::YAML::Load(shift)
    or die CPAN::Meta::YAML->errstr;
}

1;

__END__

