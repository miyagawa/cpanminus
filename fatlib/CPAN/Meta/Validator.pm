use 5.006;
use strict;
use warnings;
package CPAN::Meta::Validator;
our $VERSION = '2.120921'; # VERSION


#--------------------------------------------------------------------------#
# This code copied and adapted from Test::CPAN::Meta
# by Barbie, <barbie@cpan.org> for Miss Barbell Productions,
# L<http://www.missbarbell.co.uk>
#--------------------------------------------------------------------------#

#--------------------------------------------------------------------------#
# Specification Definitions
#--------------------------------------------------------------------------#

my %known_specs = (
    '1.4' => 'http://module-build.sourceforge.net/META-spec-v1.4.html',
    '1.3' => 'http://module-build.sourceforge.net/META-spec-v1.3.html',
    '1.2' => 'http://module-build.sourceforge.net/META-spec-v1.2.html',
    '1.1' => 'http://module-build.sourceforge.net/META-spec-v1.1.html',
    '1.0' => 'http://module-build.sourceforge.net/META-spec-v1.0.html'
);
my %known_urls = map {$known_specs{$_} => $_} keys %known_specs;

my $module_map1 = { 'map' => { ':key' => { name => \&module, value => \&exversion } } };

my $module_map2 = { 'map' => { ':key' => { name => \&module, value => \&version   } } };

my $no_index_2 = {
    'map'       => { file       => { list => { value => \&string } },
                     directory  => { list => { value => \&string } },
                     'package'  => { list => { value => \&string } },
                     namespace  => { list => { value => \&string } },
                    ':key'      => { name => \&custom_2, value => \&anything },
    }
};

my $no_index_1_3 = {
    'map'       => { file       => { list => { value => \&string } },
                     directory  => { list => { value => \&string } },
                     'package'  => { list => { value => \&string } },
                     namespace  => { list => { value => \&string } },
                     ':key'     => { name => \&string, value => \&anything },
    }
};

my $no_index_1_2 = {
    'map'       => { file       => { list => { value => \&string } },
                     dir        => { list => { value => \&string } },
                     'package'  => { list => { value => \&string } },
                     namespace  => { list => { value => \&string } },
                     ':key'     => { name => \&string, value => \&anything },
    }
};

my $no_index_1_1 = {
    'map'       => { ':key'     => { name => \&string, list => { value => \&string } },
    }
};

my $prereq_map = {
  map => {
    ':key' => {
      name => \&phase,
      'map' => {
        ':key'  => {
          name => \&relation,
          %$module_map1,
        },
      },
    }
  },
};

my %definitions = (
  '2' => {
    # REQUIRED
    'abstract'            => { mandatory => 1, value => \&string  },
    'author'              => { mandatory => 1, lazylist => { value => \&string } },
    'dynamic_config'      => { mandatory => 1, value => \&boolean },
    'generated_by'        => { mandatory => 1, value => \&string  },
    'license'             => { mandatory => 1, lazylist => { value => \&license } },
    'meta-spec' => {
      mandatory => 1,
      'map' => {
        version => { mandatory => 1, value => \&version},
        url     => { value => \&url },
        ':key' => { name => \&custom_2, value => \&anything },
      }
    },
    'name'                => { mandatory => 1, value => \&string  },
    'release_status'      => { mandatory => 1, value => \&release_status },
    'version'             => { mandatory => 1, value => \&version },

    # OPTIONAL
    'description' => { value => \&string },
    'keywords'    => { lazylist => { value => \&string } },
    'no_index'    => $no_index_2,
    'optional_features'   => {
      'map'       => {
        ':key'  => {
          name => \&string,
          'map'   => {
            description        => { value => \&string },
            prereqs => $prereq_map,
            ':key' => { name => \&custom_2, value => \&anything },
          }
        }
      }
    },
    'prereqs' => $prereq_map,
    'provides'    => {
      'map'       => {
        ':key' => {
          name  => \&module,
          'map' => {
            file    => { mandatory => 1, value => \&file },
            version => { value => \&version },
            ':key' => { name => \&custom_2, value => \&anything },
          }
        }
      }
    },
    'resources'   => {
      'map'       => {
        license    => { lazylist => { value => \&url } },
        homepage   => { value => \&url },
        bugtracker => {
          'map' => {
            web => { value => \&url },
            mailto => { value => \&string},
            ':key' => { name => \&custom_2, value => \&anything },
          }
        },
        repository => {
          'map' => {
            web => { value => \&url },
            url => { value => \&url },
            type => { value => \&string },
            ':key' => { name => \&custom_2, value => \&anything },
          }
        },
        ':key'     => { value => \&string, name => \&custom_2 },
      }
    },

    # CUSTOM -- additional user defined key/value pairs
    # note we can only validate the key name, as the structure is user defined
    ':key'        => { name => \&custom_2, value => \&anything },
  },

'1.4' => {
  'meta-spec'           => {
    mandatory => 1,
    'map' => {
      version => { mandatory => 1, value => \&version},
      url     => { mandatory => 1, value => \&urlspec },
      ':key'  => { name => \&string, value => \&anything },
    },
  },

  'name'                => { mandatory => 1, value => \&string  },
  'version'             => { mandatory => 1, value => \&version },
  'abstract'            => { mandatory => 1, value => \&string  },
  'author'              => { mandatory => 1, list  => { value => \&string } },
  'license'             => { mandatory => 1, value => \&license },
  'generated_by'        => { mandatory => 1, value => \&string  },

  'distribution_type'   => { value => \&string  },
  'dynamic_config'      => { value => \&boolean },

  'requires'            => $module_map1,
  'recommends'          => $module_map1,
  'build_requires'      => $module_map1,
  'configure_requires'  => $module_map1,
  'conflicts'           => $module_map2,

  'optional_features'   => {
    'map'       => {
        ':key'  => { name => \&string,
            'map'   => { description        => { value => \&string },
                         requires           => $module_map1,
                         recommends         => $module_map1,
                         build_requires     => $module_map1,
                         conflicts          => $module_map2,
                         ':key'  => { name => \&string, value => \&anything },
            }
        }
     }
  },

  'provides'    => {
    'map'       => {
      ':key' => { name  => \&module,
        'map' => {
          file    => { mandatory => 1, value => \&file },
          version => { value => \&version },
          ':key'  => { name => \&string, value => \&anything },
        }
      }
    }
  },

  'no_index'    => $no_index_1_3,
  'private'     => $no_index_1_3,

  'keywords'    => { list => { value => \&string } },

  'resources'   => {
    'map'       => { license    => { value => \&url },
                     homepage   => { value => \&url },
                     bugtracker => { value => \&url },
                     repository => { value => \&url },
                     ':key'     => { value => \&string, name => \&custom_1 },
    }
  },

  # additional user defined key/value pairs
  # note we can only validate the key name, as the structure is user defined
  ':key'        => { name => \&string, value => \&anything },
},

'1.3' => {
  'meta-spec'           => {
    mandatory => 1,
    'map' => {
      version => { mandatory => 1, value => \&version},
      url     => { mandatory => 1, value => \&urlspec },
      ':key'  => { name => \&string, value => \&anything },
    },
  },

  'name'                => { mandatory => 1, value => \&string  },
  'version'             => { mandatory => 1, value => \&version },
  'abstract'            => { mandatory => 1, value => \&string  },
  'author'              => { mandatory => 1, list  => { value => \&string } },
  'license'             => { mandatory => 1, value => \&license },
  'generated_by'        => { mandatory => 1, value => \&string  },

  'distribution_type'   => { value => \&string  },
  'dynamic_config'      => { value => \&boolean },

  'requires'            => $module_map1,
  'recommends'          => $module_map1,
  'build_requires'      => $module_map1,
  'conflicts'           => $module_map2,

  'optional_features'   => {
    'map'       => {
        ':key'  => { name => \&string,
            'map'   => { description        => { value => \&string },
                         requires           => $module_map1,
                         recommends         => $module_map1,
                         build_requires     => $module_map1,
                         conflicts          => $module_map2,
                         ':key'  => { name => \&string, value => \&anything },
            }
        }
     }
  },

  'provides'    => {
    'map'       => {
      ':key' => { name  => \&module,
        'map' => {
          file    => { mandatory => 1, value => \&file },
          version => { value => \&version },
          ':key'  => { name => \&string, value => \&anything },
        }
      }
    }
  },


  'no_index'    => $no_index_1_3,
  'private'     => $no_index_1_3,

  'keywords'    => { list => { value => \&string } },

  'resources'   => {
    'map'       => { license    => { value => \&url },
                     homepage   => { value => \&url },
                     bugtracker => { value => \&url },
                     repository => { value => \&url },
                     ':key'     => { value => \&string, name => \&custom_1 },
    }
  },

  # additional user defined key/value pairs
  # note we can only validate the key name, as the structure is user defined
  ':key'        => { name => \&string, value => \&anything },
},

# v1.2 is misleading, it seems to assume that a number of fields where created
# within v1.1, when they were created within v1.2. This may have been an
# original mistake, and that a v1.1 was retro fitted into the timeline, when
# v1.2 was originally slated as v1.1. But I could be wrong ;)
'1.2' => {
  'meta-spec'           => {
    mandatory => 1,
    'map' => {
      version => { mandatory => 1, value => \&version},
      url     => { mandatory => 1, value => \&urlspec },
      ':key'  => { name => \&string, value => \&anything },
    },
  },


  'name'                => { mandatory => 1, value => \&string  },
  'version'             => { mandatory => 1, value => \&version },
  'license'             => { mandatory => 1, value => \&license },
  'generated_by'        => { mandatory => 1, value => \&string  },
  'author'              => { mandatory => 1, list => { value => \&string } },
  'abstract'            => { mandatory => 1, value => \&string  },

  'distribution_type'   => { value => \&string  },
  'dynamic_config'      => { value => \&boolean },

  'keywords'            => { list => { value => \&string } },

  'private'             => $no_index_1_2,
  '$no_index'           => $no_index_1_2,

  'requires'            => $module_map1,
  'recommends'          => $module_map1,
  'build_requires'      => $module_map1,
  'conflicts'           => $module_map2,

  'optional_features'   => {
    'map'       => {
        ':key'  => { name => \&string,
            'map'   => { description        => { value => \&string },
                         requires           => $module_map1,
                         recommends         => $module_map1,
                         build_requires     => $module_map1,
                         conflicts          => $module_map2,
                         ':key'  => { name => \&string, value => \&anything },
            }
        }
     }
  },

  'provides'    => {
    'map'       => {
      ':key' => { name  => \&module,
        'map' => {
          file    => { mandatory => 1, value => \&file },
          version => { value => \&version },
          ':key'  => { name => \&string, value => \&anything },
        }
      }
    }
  },

  'resources'   => {
    'map'       => { license    => { value => \&url },
                     homepage   => { value => \&url },
                     bugtracker => { value => \&url },
                     repository => { value => \&url },
                     ':key'     => { value => \&string, name => \&custom_1 },
    }
  },

  # additional user defined key/value pairs
  # note we can only validate the key name, as the structure is user defined
  ':key'        => { name => \&string, value => \&anything },
},

# note that the 1.1 spec only specifies 'version' as mandatory
'1.1' => {
  'name'                => { value => \&string  },
  'version'             => { mandatory => 1, value => \&version },
  'license'             => { value => \&license },
  'generated_by'        => { value => \&string  },

  'license_uri'         => { value => \&url },
  'distribution_type'   => { value => \&string  },
  'dynamic_config'      => { value => \&boolean },

  'private'             => $no_index_1_1,

  'requires'            => $module_map1,
  'recommends'          => $module_map1,
  'build_requires'      => $module_map1,
  'conflicts'           => $module_map2,

  # additional user defined key/value pairs
  # note we can only validate the key name, as the structure is user defined
  ':key'        => { name => \&string, value => \&anything },
},

# note that the 1.0 spec doesn't specify optional or mandatory fields
# but we will treat version as mandatory since otherwise META 1.0 is
# completely arbitrary and pointless
'1.0' => {
  'name'                => { value => \&string  },
  'version'             => { mandatory => 1, value => \&version },
  'license'             => { value => \&license },
  'generated_by'        => { value => \&string  },

  'license_uri'         => { value => \&url },
  'distribution_type'   => { value => \&string  },
  'dynamic_config'      => { value => \&boolean },

  'requires'            => $module_map1,
  'recommends'          => $module_map1,
  'build_requires'      => $module_map1,
  'conflicts'           => $module_map2,

  # additional user defined key/value pairs
  # note we can only validate the key name, as the structure is user defined
  ':key'        => { name => \&string, value => \&anything },
},
);

#--------------------------------------------------------------------------#
# Code
#--------------------------------------------------------------------------#


sub new {
  my ($class,$data) = @_;

  # create an attributes hash
  my $self = {
    'data'    => $data,
    'spec'    => $data->{'meta-spec'}{'version'} || "1.0",
    'errors'  => undef,
  };

  # create the object
  return bless $self, $class;
}


sub is_valid {
    my $self = shift;
    my $data = $self->{data};
    my $spec_version = $self->{spec};
    $self->check_map($definitions{$spec_version},$data);
    return ! $self->errors;
}


sub errors {
    my $self = shift;
    return ()   unless(defined $self->{errors});
    return @{$self->{errors}};
}


my $spec_error = "Missing validation action in specification. "
  . "Must be one of 'map', 'list', 'lazylist', or 'value'";

sub check_map {
    my ($self,$spec,$data) = @_;

    if(ref($spec) ne 'HASH') {
        $self->_error( "Unknown META specification, cannot validate." );
        return;
    }

    if(ref($data) ne 'HASH') {
        $self->_error( "Expected a map structure from string or file." );
        return;
    }

    for my $key (keys %$spec) {
        next    unless($spec->{$key}->{mandatory});
        next    if(defined $data->{$key});
        push @{$self->{stack}}, $key;
        $self->_error( "Missing mandatory field, '$key'" );
        pop @{$self->{stack}};
    }

    for my $key (keys %$data) {
        push @{$self->{stack}}, $key;
        if($spec->{$key}) {
            if($spec->{$key}{value}) {
                $spec->{$key}{value}->($self,$key,$data->{$key});
            } elsif($spec->{$key}{'map'}) {
                $self->check_map($spec->{$key}{'map'},$data->{$key});
            } elsif($spec->{$key}{'list'}) {
                $self->check_list($spec->{$key}{'list'},$data->{$key});
            } elsif($spec->{$key}{'lazylist'}) {
                $self->check_lazylist($spec->{$key}{'lazylist'},$data->{$key});
            } else {
                $self->_error( "$spec_error for '$key'" );
            }

        } elsif ($spec->{':key'}) {
            $spec->{':key'}{name}->($self,$key,$key);
            if($spec->{':key'}{value}) {
                $spec->{':key'}{value}->($self,$key,$data->{$key});
            } elsif($spec->{':key'}{'map'}) {
                $self->check_map($spec->{':key'}{'map'},$data->{$key});
            } elsif($spec->{':key'}{'list'}) {
                $self->check_list($spec->{':key'}{'list'},$data->{$key});
            } elsif($spec->{':key'}{'lazylist'}) {
                $self->check_lazylist($spec->{':key'}{'lazylist'},$data->{$key});
            } else {
                $self->_error( "$spec_error for ':key'" );
            }


        } else {
            $self->_error( "Unknown key, '$key', found in map structure" );
        }
        pop @{$self->{stack}};
    }
}

# if it's a string, make it into a list and check the list
sub check_lazylist {
    my ($self,$spec,$data) = @_;

    if ( defined $data && ! ref($data) ) {
      $data = [ $data ];
    }

    $self->check_list($spec,$data);
}

sub check_list {
    my ($self,$spec,$data) = @_;

    if(ref($data) ne 'ARRAY') {
        $self->_error( "Expected a list structure" );
        return;
    }

    if(defined $spec->{mandatory}) {
        if(!defined $data->[0]) {
            $self->_error( "Missing entries from mandatory list" );
        }
    }

    for my $value (@$data) {
        push @{$self->{stack}}, $value || "<undef>";
        if(defined $spec->{value}) {
            $spec->{value}->($self,'list',$value);
        } elsif(defined $spec->{'map'}) {
            $self->check_map($spec->{'map'},$value);
        } elsif(defined $spec->{'list'}) {
            $self->check_list($spec->{'list'},$value);
        } elsif(defined $spec->{'lazylist'}) {
            $self->check_lazylist($spec->{'lazylist'},$value);
        } elsif ($spec->{':key'}) {
            $self->check_map($spec,$value);
        } else {
          $self->_error( "$spec_error associated with '$self->{stack}[-2]'" );
        }
        pop @{$self->{stack}};
    }
}


sub header {
    my ($self,$key,$value) = @_;
    if(defined $value) {
        return 1    if($value && $value =~ /^--- #YAML:1.0/);
    }
    $self->_error( "file does not have a valid YAML header." );
    return 0;
}

sub release_status {
  my ($self,$key,$value) = @_;
  if(defined $value) {
    my $version = $self->{data}{version} || '';
    if ( $version =~ /_/ ) {
      return 1 if ( $value =~ /\A(?:testing|unstable)\z/ );
      $self->_error( "'$value' for '$key' is invalid for version '$version'" );
    }
    else {
      return 1 if ( $value =~ /\A(?:stable|testing|unstable)\z/ );
      $self->_error( "'$value' for '$key' is invalid" );
    }
  }
  else {
    $self->_error( "'$key' is not defined" );
  }
  return 0;
}

# _uri_split taken from URI::Split by Gisle Aas, Copyright 2003
sub _uri_split {
     return $_[0] =~ m,(?:([^:/?#]+):)?(?://([^/?#]*))?([^?#]*)(?:\?([^#]*))?(?:#(.*))?,;
}

sub url {
    my ($self,$key,$value) = @_;
    if(defined $value) {
      my ($scheme, $auth, $path, $query, $frag) = _uri_split($value);
      unless ( defined $scheme && length $scheme ) {
        $self->_error( "'$value' for '$key' does not have a URL scheme" );
        return 0;
      }
      unless ( defined $auth && length $auth ) {
        $self->_error( "'$value' for '$key' does not have a URL authority" );
        return 0;
      }
      return 1;
    }
    $value ||= '';
    $self->_error( "'$value' for '$key' is not a valid URL." );
    return 0;
}

sub urlspec {
    my ($self,$key,$value) = @_;
    if(defined $value) {
        return 1    if($value && $known_specs{$self->{spec}} eq $value);
        if($value && $known_urls{$value}) {
            $self->_error( 'META specification URL does not match version' );
            return 0;
        }
    }
    $self->_error( 'Unknown META specification' );
    return 0;
}

sub anything { return 1 }

sub string {
    my ($self,$key,$value) = @_;
    if(defined $value) {
        return 1    if($value || $value =~ /^0$/);
    }
    $self->_error( "value is an undefined string" );
    return 0;
}

sub string_or_undef {
    my ($self,$key,$value) = @_;
    return 1    unless(defined $value);
    return 1    if($value || $value =~ /^0$/);
    $self->_error( "No string defined for '$key'" );
    return 0;
}

sub file {
    my ($self,$key,$value) = @_;
    return 1    if(defined $value);
    $self->_error( "No file defined for '$key'" );
    return 0;
}

sub exversion {
    my ($self,$key,$value) = @_;
    if(defined $value && ($value || $value =~ /0/)) {
        my $pass = 1;
        for(split(",",$value)) { $self->version($key,$_) or ($pass = 0); }
        return $pass;
    }
    $value = '<undef>'  unless(defined $value);
    $self->_error( "'$value' for '$key' is not a valid version." );
    return 0;
}

sub version {
    my ($self,$key,$value) = @_;
    if(defined $value) {
        return 0    unless($value || $value =~ /0/);
        return 1    if($value =~ /^\s*((<|<=|>=|>|!=|==)\s*)?v?\d+((\.\d+((_|\.)\d+)?)?)/);
    } else {
        $value = '<undef>';
    }
    $self->_error( "'$value' for '$key' is not a valid version." );
    return 0;
}

sub boolean {
    my ($self,$key,$value) = @_;
    if(defined $value) {
        return 1    if($value =~ /^(0|1|true|false)$/);
    } else {
        $value = '<undef>';
    }
    $self->_error( "'$value' for '$key' is not a boolean value." );
    return 0;
}

my %v1_licenses = (
    'perl'         => 'http://dev.perl.org/licenses/',
    'gpl'          => 'http://www.opensource.org/licenses/gpl-license.php',
    'apache'       => 'http://apache.org/licenses/LICENSE-2.0',
    'artistic'     => 'http://opensource.org/licenses/artistic-license.php',
    'artistic_2'   => 'http://opensource.org/licenses/artistic-license-2.0.php',
    'lgpl'         => 'http://www.opensource.org/licenses/lgpl-license.php',
    'bsd'          => 'http://www.opensource.org/licenses/bsd-license.php',
    'gpl'          => 'http://www.opensource.org/licenses/gpl-license.php',
    'mit'          => 'http://opensource.org/licenses/mit-license.php',
    'mozilla'      => 'http://opensource.org/licenses/mozilla1.1.php',
    'open_source'  => undef,
    'unrestricted' => undef,
    'restrictive'  => undef,
    'unknown'      => undef,
);

my %v2_licenses = map { $_ => 1 } qw(
  agpl_3
  apache_1_1
  apache_2_0
  artistic_1
  artistic_2
  bsd
  freebsd
  gfdl_1_2
  gfdl_1_3
  gpl_1
  gpl_2
  gpl_3
  lgpl_2_1
  lgpl_3_0
  mit
  mozilla_1_0
  mozilla_1_1
  openssl
  perl_5
  qpl_1_0
  ssleay
  sun
  zlib
  open_source
  restricted
  unrestricted
  unknown
);

sub license {
    my ($self,$key,$value) = @_;
    my $licenses = $self->{spec} < 2 ? \%v1_licenses : \%v2_licenses;
    if(defined $value) {
        return 1    if($value && exists $licenses->{$value});
    } else {
        $value = '<undef>';
    }
    $self->_error( "License '$value' is invalid" );
    return 0;
}

sub custom_1 {
    my ($self,$key) = @_;
    if(defined $key) {
        # a valid user defined key should be alphabetic
        # and contain at least one capital case letter.
        return 1    if($key && $key =~ /^[_a-z]+$/i && $key =~ /[A-Z]/);
    } else {
        $key = '<undef>';
    }
    $self->_error( "Custom resource '$key' must be in CamelCase." );
    return 0;
}

sub custom_2 {
    my ($self,$key) = @_;
    if(defined $key) {
        return 1    if($key && $key =~ /^x_/i);  # user defined
    } else {
        $key = '<undef>';
    }
    $self->_error( "Custom key '$key' must begin with 'x_' or 'X_'." );
    return 0;
}

sub identifier {
    my ($self,$key) = @_;
    if(defined $key) {
        return 1    if($key && $key =~ /^([a-z][_a-z]+)$/i);    # spec 2.0 defined
    } else {
        $key = '<undef>';
    }
    $self->_error( "Key '$key' is not a legal identifier." );
    return 0;
}

sub module {
    my ($self,$key) = @_;
    if(defined $key) {
        return 1    if($key && $key =~ /^[A-Za-z0-9_]+(::[A-Za-z0-9_]+)*$/);
    } else {
        $key = '<undef>';
    }
    $self->_error( "Key '$key' is not a legal module name." );
    return 0;
}

my @valid_phases = qw/ configure build test runtime develop /;
sub phase {
    my ($self,$key) = @_;
    if(defined $key) {
        return 1 if( length $key && grep { $key eq $_ } @valid_phases );
        return 1 if $key =~ /x_/i;
    } else {
        $key = '<undef>';
    }
    $self->_error( "Key '$key' is not a legal phase." );
    return 0;
}

my @valid_relations = qw/ requires recommends suggests conflicts /;
sub relation {
    my ($self,$key) = @_;
    if(defined $key) {
        return 1 if( length $key && grep { $key eq $_ } @valid_relations );
        return 1 if $key =~ /x_/i;
    } else {
        $key = '<undef>';
    }
    $self->_error( "Key '$key' is not a legal prereq relationship." );
    return 0;
}

sub _error {
    my $self = shift;
    my $mess = shift;

    $mess .= ' ('.join(' -> ',@{$self->{stack}}).')'  if($self->{stack});
    $mess .= " [Validation: $self->{spec}]";

    push @{$self->{errors}}, $mess;
}

1;

# ABSTRACT: validate CPAN distribution metadata structures




__END__



