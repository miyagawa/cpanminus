# -*- mode: cperl; tab-width: 8; indent-tabs-mode: nil; basic-offset: 2 -*-
# vim:ts=8:sw=2:et:sta:sts=2
package Module::Metadata;

# Adapted from Perl-licensed code originally distributed with
# Module-Build by Ken Williams

# This module provides routines to gather information about
# perl modules (assuming this may be expanded in the distant
# parrot future to look at other types of modules).

use strict;
use vars qw($VERSION);
$VERSION = '1.000007';
$VERSION = eval $VERSION;

use File::Spec;
use IO::File;
use version 0.87;
BEGIN {
  if ($INC{'Log/Contextual.pm'}) {
    Log::Contextual->import('log_info');
  } else {
    *log_info = sub (&) { warn $_[0]->() };
  }
}
use File::Find qw(find);

my $V_NUM_REGEXP = qr{v?[0-9._]+};  # crudely, a v-string or decimal

my $PKG_REGEXP  = qr{   # match a package declaration
  ^[\s\{;]*             # intro chars on a line
  package               # the word 'package'
  \s+                   # whitespace
  ([\w:]+)              # a package name
  \s*                   # optional whitespace
  ($V_NUM_REGEXP)?        # optional version number
  \s*                   # optional whitesapce
  [;\{]                 # semicolon line terminator or block start (since 5.16)
}x;

my $VARNAME_REGEXP = qr{ # match fully-qualified VERSION name
  ([\$*])         # sigil - $ or *
  (
    (             # optional leading package name
      (?:::|\')?  # possibly starting like just :: (�  la $::VERSION)
      (?:\w+(?:::|\'))*  # Foo::Bar:: ...
    )?
    VERSION
  )\b
}x;

my $VERS_REGEXP = qr{ # match a VERSION definition
  (?:
    \(\s*$VARNAME_REGEXP\s*\) # with parens
  |
    $VARNAME_REGEXP           # without parens
  )
  \s*
  =[^=~]  # = but not ==, nor =~
}x;


sub new_from_file {
  my $class    = shift;
  my $filename = File::Spec->rel2abs( shift );

  return undef unless defined( $filename ) && -f $filename;
  return $class->_init(undef, $filename, @_);
}

sub new_from_handle {
  my $class    = shift;
  my $handle   = shift;
  my $filename = shift;
  return undef unless defined($handle) && defined($filename);
  $filename = File::Spec->rel2abs( $filename );

  return $class->_init(undef, $filename, @_, handle => $handle);

}


sub new_from_module {
  my $class   = shift;
  my $module  = shift;
  my %props   = @_;

  $props{inc} ||= \@INC;
  my $filename = $class->find_module_by_name( $module, $props{inc} );
  return undef unless defined( $filename ) && -f $filename;
  return $class->_init($module, $filename, %props);
}

{
  
  my $compare_versions = sub {
    my ($v1, $op, $v2) = @_;
    $v1 = version->new($v1)
      unless UNIVERSAL::isa($v1,'version');
  
    my $eval_str = "\$v1 $op \$v2";
    my $result   = eval $eval_str;
    log_info { "error comparing versions: '$eval_str' $@" } if $@;
  
    return $result;
  };

  my $normalize_version = sub {
    my ($version) = @_;
    if ( $version =~ /[=<>!,]/ ) { # logic, not just version
      # take as is without modification
    }
    elsif ( ref $version eq 'version' ) { # version objects
      $version = $version->is_qv ? $version->normal : $version->stringify;
    }
    elsif ( $version =~ /^[^v][^.]*\.[^.]+\./ ) { # no leading v, multiple dots
      # normalize string tuples without "v": "1.2.3" -> "v1.2.3"
      $version = "v$version";
    }
    else {
      # leave alone
    }
    return $version;
  };

  # separate out some of the conflict resolution logic

  my $resolve_module_versions = sub {
    my $packages = shift;
  
    my( $file, $version );
    my $err = '';
      foreach my $p ( @$packages ) {
        if ( defined( $p->{version} ) ) {
  	if ( defined( $version ) ) {
   	  if ( $compare_versions->( $version, '!=', $p->{version} ) ) {
  	    $err .= "  $p->{file} ($p->{version})\n";
  	  } else {
  	    # same version declared multiple times, ignore
  	  }
  	} else {
  	  $file    = $p->{file};
  	  $version = $p->{version};
  	}
        }
        $file ||= $p->{file} if defined( $p->{file} );
      }
  
    if ( $err ) {
      $err = "  $file ($version)\n" . $err;
    }
  
    my %result = (
      file    => $file,
      version => $version,
      err     => $err
    );
  
    return \%result;
  };

  sub package_versions_from_directory {
    my ( $class, $dir, $files ) = @_;

    my @files;

    if ( $files ) {
      @files = @$files;
    } else {
      find( {
        wanted => sub {
          push @files, $_ if -f $_ && /\.pm$/;
        },
        no_chdir => 1,
      }, $dir );
    }

    # First, we enumerate all packages & versions,
    # separating into primary & alternative candidates
    my( %prime, %alt );
    foreach my $file (@files) {
      my $mapped_filename = File::Spec->abs2rel( $file, $dir );
      my @path = split( /\//, $mapped_filename );
      (my $prime_package = join( '::', @path )) =~ s/\.pm$//;
  
      my $pm_info = $class->new_from_file( $file );
  
      foreach my $package ( $pm_info->packages_inside ) {
        next if $package eq 'main';  # main can appear numerous times, ignore
        next if $package eq 'DB';    # special debugging package, ignore
        next if grep /^_/, split( /::/, $package ); # private package, ignore
  
        my $version = $pm_info->version( $package );
  
        if ( $package eq $prime_package ) {
          if ( exists( $prime{$package} ) ) {
            die "Unexpected conflict in '$package'; multiple versions found.\n";
          } else {
            $prime{$package}{file} = $mapped_filename;
            $prime{$package}{version} = $version if defined( $version );
          }
        } else {
          push( @{$alt{$package}}, {
                                    file    => $mapped_filename,
                                    version => $version,
                                   } );
        }
      }
    }
  
    # Then we iterate over all the packages found above, identifying conflicts
    # and selecting the "best" candidate for recording the file & version
    # for each package.
    foreach my $package ( keys( %alt ) ) {
      my $result = $resolve_module_versions->( $alt{$package} );
  
      if ( exists( $prime{$package} ) ) { # primary package selected
  
        if ( $result->{err} ) {
  	# Use the selected primary package, but there are conflicting
  	# errors among multiple alternative packages that need to be
  	# reported
          log_info {
  	    "Found conflicting versions for package '$package'\n" .
  	    "  $prime{$package}{file} ($prime{$package}{version})\n" .
  	    $result->{err}
          };
  
        } elsif ( defined( $result->{version} ) ) {
  	# There is a primary package selected, and exactly one
  	# alternative package
  
  	if ( exists( $prime{$package}{version} ) &&
  	     defined( $prime{$package}{version} ) ) {
  	  # Unless the version of the primary package agrees with the
  	  # version of the alternative package, report a conflict
  	  if ( $compare_versions->(
                 $prime{$package}{version}, '!=', $result->{version}
               )
             ) {

            log_info {
              "Found conflicting versions for package '$package'\n" .
  	      "  $prime{$package}{file} ($prime{$package}{version})\n" .
  	      "  $result->{file} ($result->{version})\n"
            };
  	  }
  
  	} else {
  	  # The prime package selected has no version so, we choose to
  	  # use any alternative package that does have a version
  	  $prime{$package}{file}    = $result->{file};
  	  $prime{$package}{version} = $result->{version};
  	}
  
        } else {
  	# no alt package found with a version, but we have a prime
  	# package so we use it whether it has a version or not
        }
  
      } else { # No primary package was selected, use the best alternative
  
        if ( $result->{err} ) {
          log_info {
            "Found conflicting versions for package '$package'\n" .
  	    $result->{err}
          };
        }
  
        # Despite possible conflicting versions, we choose to record
        # something rather than nothing
        $prime{$package}{file}    = $result->{file};
        $prime{$package}{version} = $result->{version}
  	  if defined( $result->{version} );
      }
    }
  
    # Normalize versions.  Can't use exists() here because of bug in YAML::Node.
    # XXX "bug in YAML::Node" comment seems irrelvant -- dagolden, 2009-05-18
    for (grep defined $_->{version}, values %prime) {
      $_->{version} = $normalize_version->( $_->{version} );
    }
  
    return \%prime;
  }
} 
  

sub _init {
  my $class    = shift;
  my $module   = shift;
  my $filename = shift;
  my %props = @_;

  my $handle = delete $props{handle};
  my( %valid_props, @valid_props );
  @valid_props = qw( collect_pod inc );
  @valid_props{@valid_props} = delete( @props{@valid_props} );
  warn "Unknown properties: @{[keys %props]}\n" if scalar( %props );

  my %data = (
    module       => $module,
    filename     => $filename,
    version      => undef,
    packages     => [],
    versions     => {},
    pod          => {},
    pod_headings => [],
    collect_pod  => 0,

    %valid_props,
  );

  my $self = bless(\%data, $class);

  if ( $handle ) {
    $self->_parse_fh($handle);
  }
  else {
    $self->_parse_file();
  }

  unless($self->{module} and length($self->{module})) {
    my ($v, $d, $f) = File::Spec->splitpath($self->{filename});
    if($f =~ /\.pm$/) {
      $f =~ s/\..+$//;
      my @candidates = grep /$f$/, @{$self->{packages}};
      $self->{module} = shift(@candidates); # punt
    }
    else {
      if(grep /main/, @{$self->{packages}}) {
        $self->{module} = 'main';
      }
      else {
        $self->{module} = $self->{packages}[0] || '';
      }
    }
  }

  $self->{version} = $self->{versions}{$self->{module}}
      if defined( $self->{module} );

  return $self;
}

# class method
sub _do_find_module {
  my $class   = shift;
  my $module  = shift || die 'find_module_by_name() requires a package name';
  my $dirs    = shift || \@INC;

  my $file = File::Spec->catfile(split( /::/, $module));
  foreach my $dir ( @$dirs ) {
    my $testfile = File::Spec->catfile($dir, $file);
    return [ File::Spec->rel2abs( $testfile ), $dir ]
	if -e $testfile and !-d _;  # For stuff like ExtUtils::xsubpp
    return [ File::Spec->rel2abs( "$testfile.pm" ), $dir ]
	if -e "$testfile.pm";
  }
  return;
}

# class method
sub find_module_by_name {
  my $found = shift()->_do_find_module(@_) or return;
  return $found->[0];
}

# class method
sub find_module_dir_by_name {
  my $found = shift()->_do_find_module(@_) or return;
  return $found->[1];
}


# given a line of perl code, attempt to parse it if it looks like a
# $VERSION assignment, returning sigil, full name, & package name
sub _parse_version_expression {
  my $self = shift;
  my $line = shift;

  my( $sig, $var, $pkg );
  if ( $line =~ $VERS_REGEXP ) {
    ( $sig, $var, $pkg ) = $2 ? ( $1, $2, $3 ) : ( $4, $5, $6 );
    if ( $pkg ) {
      $pkg = ($pkg eq '::') ? 'main' : $pkg;
      $pkg =~ s/::$//;
    }
  }

  return ( $sig, $var, $pkg );
}

sub _parse_file {
  my $self = shift;

  my $filename = $self->{filename};
  my $fh = IO::File->new( $filename )
    or die( "Can't open '$filename': $!" );

  $self->_parse_fh($fh);
}

sub _parse_fh {
  my ($self, $fh) = @_;

  my( $in_pod, $seen_end, $need_vers ) = ( 0, 0, 0 );
  my( @pkgs, %vers, %pod, @pod );
  my $pkg = 'main';
  my $pod_sect = '';
  my $pod_data = '';

  while (defined( my $line = <$fh> )) {
    my $line_num = $.;

    chomp( $line );
    next if $line =~ /^\s*#/;

    $in_pod = ($line =~ /^=(?!cut)/) ? 1 : ($line =~ /^=cut/) ? 0 : $in_pod;

    # Would be nice if we could also check $in_string or something too
    last if !$in_pod && $line =~ /^__(?:DATA|END)__$/;

    if ( $in_pod || $line =~ /^=cut/ ) {

      if ( $line =~ /^=head\d\s+(.+)\s*$/ ) {
	push( @pod, $1 );
	if ( $self->{collect_pod} && length( $pod_data ) ) {
          $pod{$pod_sect} = $pod_data;
          $pod_data = '';
        }
	$pod_sect = $1;


      } elsif ( $self->{collect_pod} ) {
	$pod_data .= "$line\n";

      }

    } else {

      $pod_sect = '';
      $pod_data = '';

      # parse $line to see if it's a $VERSION declaration
      my( $vers_sig, $vers_fullname, $vers_pkg ) =
	  $self->_parse_version_expression( $line );

      if ( $line =~ $PKG_REGEXP ) {
        $pkg = $1;
        push( @pkgs, $pkg ) unless grep( $pkg eq $_, @pkgs );
        $vers{$pkg} = (defined $2 ? $2 : undef)  unless exists( $vers{$pkg} );
        $need_vers = defined $2 ? 0 : 1;

      # VERSION defined with full package spec, i.e. $Module::VERSION
      } elsif ( $vers_fullname && $vers_pkg ) {
	push( @pkgs, $vers_pkg ) unless grep( $vers_pkg eq $_, @pkgs );
	$need_vers = 0 if $vers_pkg eq $pkg;

	unless ( defined $vers{$vers_pkg} && length $vers{$vers_pkg} ) {
	  $vers{$vers_pkg} =
	    $self->_evaluate_version_line( $vers_sig, $vers_fullname, $line );
	} else {
	  # Warn unless the user is using the "$VERSION = eval
	  # $VERSION" idiom (though there are probably other idioms
	  # that we should watch out for...)
	  warn <<"EOM" unless $line =~ /=\s*eval/;
Package '$vers_pkg' already declared with version '$vers{$vers_pkg}',
ignoring subsequent declaration on line $line_num.
EOM
	}

      # first non-comment line in undeclared package main is VERSION
      } elsif ( !exists($vers{main}) && $pkg eq 'main' && $vers_fullname ) {
	$need_vers = 0;
	my $v =
	  $self->_evaluate_version_line( $vers_sig, $vers_fullname, $line );
	$vers{$pkg} = $v;
	push( @pkgs, 'main' );

      # first non-comment line in undeclared package defines package main
      } elsif ( !exists($vers{main}) && $pkg eq 'main' && $line =~ /\w+/ ) {
	$need_vers = 1;
	$vers{main} = '';
	push( @pkgs, 'main' );

      # only keep if this is the first $VERSION seen
      } elsif ( $vers_fullname && $need_vers ) {
	$need_vers = 0;
	my $v =
	  $self->_evaluate_version_line( $vers_sig, $vers_fullname, $line );


	unless ( defined $vers{$pkg} && length $vers{$pkg} ) {
	  $vers{$pkg} = $v;
	} else {
	  warn <<"EOM";
Package '$pkg' already declared with version '$vers{$pkg}'
ignoring new version '$v' on line $line_num.
EOM
	}

      }

    }

  }

  if ( $self->{collect_pod} && length($pod_data) ) {
    $pod{$pod_sect} = $pod_data;
  }

  $self->{versions} = \%vers;
  $self->{packages} = \@pkgs;
  $self->{pod} = \%pod;
  $self->{pod_headings} = \@pod;
}

{
my $pn = 0;
sub _evaluate_version_line {
  my $self = shift;
  my( $sigil, $var, $line ) = @_;

  # Some of this code came from the ExtUtils:: hierarchy.

  # We compile into $vsub because 'use version' would cause
  # compiletime/runtime issues with local()
  my $vsub;
  $pn++; # everybody gets their own package
  my $eval = qq{BEGIN { q#  Hide from _packages_inside()
    #; package Module::Metadata::_version::p$pn;
    use version;
    no strict;

      \$vsub = sub {
        local $sigil$var;
        \$$var=undef;
        $line;
        \$$var
      };
  }};

  local $^W;
  # Try to get the $VERSION
  eval $eval;
  # some modules say $VERSION = $Foo::Bar::VERSION, but Foo::Bar isn't
  # installed, so we need to hunt in ./lib for it
  if ( $@ =~ /Can't locate/ && -d 'lib' ) {
    local @INC = ('lib',@INC);
    eval $eval;
  }
  warn "Error evaling version line '$eval' in $self->{filename}: $@\n"
    if $@;
  (ref($vsub) eq 'CODE') or
    die "failed to build version sub for $self->{filename}";
  my $result = eval { $vsub->() };
  die "Could not get version from $self->{filename} by executing:\n$eval\n\nThe fatal error was: $@\n"
    if $@;

  # Upgrade it into a version object
  my $version = eval { _dwim_version($result) };

  die "Version '$result' from $self->{filename} does not appear to be valid:\n$eval\n\nThe fatal error was: $@\n"
    unless defined $version; # "0" is OK!

  return $version;
}
}

# Try to DWIM when things fail the lax version test in obvious ways
{
  my @version_prep = (
    # Best case, it just works
    sub { return shift },

    # If we still don't have a version, try stripping any
    # trailing junk that is prohibited by lax rules
    sub {
      my $v = shift;
      $v =~ s{([0-9])[a-z-].*$}{$1}i; # 1.23-alpha or 1.23b
      return $v;
    },

    # Activestate apparently creates custom versions like '1.23_45_01', which
    # cause version.pm to think it's an invalid alpha.  So check for that
    # and strip them
    sub {
      my $v = shift;
      my $num_dots = () = $v =~ m{(\.)}g;
      my $num_unders = () = $v =~ m{(_)}g;
      my $leading_v = substr($v,0,1) eq 'v';
      if ( ! $leading_v && $num_dots < 2 && $num_unders > 1 ) {
        $v =~ s{_}{}g;
        $num_unders = () = $v =~ m{(_)}g;
      }
      return $v;
    },

    # Worst case, try numifying it like we would have before version objects
    sub {
      my $v = shift;
      no warnings 'numeric';
      return 0 + $v;
    },

  );

  sub _dwim_version {
    my ($result) = shift;

    return $result if ref($result) eq 'version';

    my ($version, $error);
    for my $f (@version_prep) {
      $result = $f->($result);
      $version = eval { version->new($result) };
      $error ||= $@ if $@; # capture first failure
      last if defined $version;
    }

    die $error unless defined $version;

    return $version;
  }
}

############################################################

# accessors
sub name            { $_[0]->{module}           }

sub filename        { $_[0]->{filename}         }
sub packages_inside { @{$_[0]->{packages}}      }
sub pod_inside      { @{$_[0]->{pod_headings}}  }
sub contains_pod    { $#{$_[0]->{pod_headings}} }

sub version {
    my $self = shift;
    my $mod  = shift || $self->{module};
    my $vers;
    if ( defined( $mod ) && length( $mod ) &&
	 exists( $self->{versions}{$mod} ) ) {
	return $self->{versions}{$mod};
    } else {
	return undef;
    }
}

sub pod {
    my $self = shift;
    my $sect = shift;
    if ( defined( $sect ) && length( $sect ) &&
	 exists( $self->{pod}{$sect} ) ) {
	return $self->{pod}{$sect};
    } else {
	return undef;
    }
}

1;

