use strict;
use warnings;

package local::lib;

use 5.008001; # probably works with earlier versions but I'm not supporting them
              # (patches would, of course, be welcome)

use File::Spec ();
use File::Path ();
use Carp ();
use Config;

our $VERSION = '1.008004'; # 1.8.4

our @KNOWN_FLAGS = qw(--self-contained --deactivate --deactivate-all);

sub DEACTIVATE_ONE () { 1 }
sub DEACTIVATE_ALL () { 2 }

sub INTERPOLATE_ENV () { 1 }
sub LITERAL_ENV     () { 0 }

sub import {
  my ($class, @args) = @_;

  # Remember what PERL5LIB was when we started
  my $perl5lib = $ENV{PERL5LIB} || '';

  my %arg_store;
  for my $arg (@args) {
    # check for lethal dash first to stop processing before causing problems
    if ($arg =~ /−/) {
      die <<'DEATH';
WHOA THERE! It looks like you've got some fancy dashes in your commandline!
These are *not* the traditional -- dashes that software recognizes. You
probably got these by copy-pasting from the perldoc for this module as
rendered by a UTF8-capable formatter. This most typically happens on an OS X
terminal, but can happen elsewhere too. Please try again after replacing the
dashes with normal minus signs.
DEATH
    }
    elsif(grep { $arg eq $_ } @KNOWN_FLAGS) {
      (my $flag = $arg) =~ s/--//;
      $arg_store{$flag} = 1;
    }
    elsif($arg =~ /^--/) {
      die "Unknown import argument: $arg";
    }
    else {
      # assume that what's left is a path
      $arg_store{path} = $arg;
    }
  }

  if($arg_store{'self-contained'}) {
    die "FATAL: The local::lib --self-contained flag has never worked reliably and the original author, Mark Stosberg, was unable or unwilling to maintain it. As such, this flag has been removed from the local::lib codebase in order to prevent misunderstandings and potentially broken builds. The local::lib authors recommend that you look at the lib::core::only module shipped with this distribution in order to create a more robust environment that is equivalent to what --self-contained provided (although quite possibly not what you originally thought it provided due to the poor quality of the documentation, for which we apologise).\n";
  }

  my $deactivating = 0;
  if ($arg_store{deactivate}) {
    $deactivating = DEACTIVATE_ONE;
  }
  if ($arg_store{'deactivate-all'}) {
    $deactivating = DEACTIVATE_ALL;
  }

  $arg_store{path} = $class->resolve_path($arg_store{path});
  $class->setup_local_lib_for($arg_store{path}, $deactivating);

  for (@INC) { # Untaint @INC
    next if ref; # Skip entry if it is an ARRAY, CODE, blessed, etc.
    m/(.*)/ and $_ = $1;
  }
}

sub pipeline;

sub pipeline {
  my @methods = @_;
  my $last = pop(@methods);
  if (@methods) {
    \sub {
      my ($obj, @args) = @_;
      $obj->${pipeline @methods}(
        $obj->$last(@args)
      );
    };
  } else {
    \sub {
      shift->$last(@_);
    };
  }
}

sub _uniq {
    my %seen;
    grep { ! $seen{$_}++ } @_;
}

sub resolve_path {
  my ($class, $path) = @_;
  $class->${pipeline qw(
    resolve_relative_path
    resolve_home_path
    resolve_empty_path
  )}($path);
}

sub resolve_empty_path {
  my ($class, $path) = @_;
  if (defined $path) {
    $path;
  } else {
    '~/perl5';
  }
}

sub resolve_home_path {
  my ($class, $path) = @_;
  return $path unless ($path =~ /^~/);
  my ($user) = ($path =~ /^~([^\/]+)/); # can assume ^~ so undef for 'us'
  my $tried_file_homedir;
  my $homedir = do {
    if (eval { require File::HomeDir } && $File::HomeDir::VERSION >= 0.65) {
      $tried_file_homedir = 1;
      if (defined $user) {
        File::HomeDir->users_home($user);
      } else {
        File::HomeDir->my_home;
      }
    } else {
      if (defined $user) {
        (getpwnam $user)[7];
      } else {
        if (defined $ENV{HOME}) {
          $ENV{HOME};
        } else {
          (getpwuid $<)[7];
        }
      }
    }
  };
  unless (defined $homedir) {
    Carp::croak(
      "Couldn't resolve homedir for "
      .(defined $user ? $user : 'current user')
      .($tried_file_homedir ? '' : ' - consider installing File::HomeDir')
    );
  }
  $path =~ s/^~[^\/]*/$homedir/;
  $path;
}

sub resolve_relative_path {
  my ($class, $path) = @_;
  $path = File::Spec->rel2abs($path);
}

sub setup_local_lib_for {
  my ($class, $path, $deactivating) = @_;

  my $interpolate = LITERAL_ENV;
  my @active_lls = $class->active_paths;

  $path = $class->ensure_dir_structure_for($path);

  if (! $deactivating) {
    if (@active_lls && $active_lls[-1] eq $path) {
      exit 0 if $0 eq '-';
      return; # Asked to add what's already at the top of the stack
    } elsif (grep { $_ eq $path} @active_lls) {
      # Asked to add a dir that's lower in the stack -- so we remove it from
      # where it is, and then add it back at the top.
      $class->setup_env_hash_for($path, DEACTIVATE_ONE);
      # Which means we can no longer output "PERL5LIB=...:$PERL5LIB" stuff
      # anymore because we're taking something *out*.
      $interpolate = INTERPOLATE_ENV;
    }
  }

  if ($0 eq '-') {
    $class->print_environment_vars_for($path, $deactivating, $interpolate);
    exit 0;
  } else {
    $class->setup_env_hash_for($path, $deactivating);
    @INC = _uniq(split($Config{path_sep}, $ENV{PERL5LIB}), @INC);
  }
}

sub install_base_bin_path {
  my ($class, $path) = @_;
  File::Spec->catdir($path, 'bin');
}

sub install_base_perl_path {
  my ($class, $path) = @_;
  File::Spec->catdir($path, 'lib', 'perl5');
}

sub install_base_arch_path {
  my ($class, $path) = @_;
  File::Spec->catdir($class->install_base_perl_path($path), $Config{archname});
}

sub ensure_dir_structure_for {
  my ($class, $path) = @_;
  unless (-d $path) {
    warn "Attempting to create directory ${path}\n";
  }
  File::Path::mkpath($path);
  # Need to have the path exist to make a short name for it, so
  # converting to a short name here.
  $path = Win32::GetShortPathName($path) if $^O eq 'MSWin32';

  return $path;
}

sub guess_shelltype {
  my $shellbin = 'sh';
  if(defined $ENV{'SHELL'}) {
      my @shell_bin_path_parts = File::Spec->splitpath($ENV{'SHELL'});
      $shellbin = $shell_bin_path_parts[-1];
  }
  my $shelltype = do {
      local $_ = $shellbin;
      if(/csh/) {
          'csh'
      } else {
          'bourne'
      }
  };

  # Both Win32 and Cygwin have $ENV{COMSPEC} set.
  if (defined $ENV{'COMSPEC'} && $^O ne 'cygwin') {
      my @shell_bin_path_parts = File::Spec->splitpath($ENV{'COMSPEC'});
      $shellbin = $shell_bin_path_parts[-1];
         $shelltype = do {
                 local $_ = $shellbin;
                 if(/command\.com/) {
                         'win32'
                 } elsif(/cmd\.exe/) {
                         'win32'
                 } elsif(/4nt\.exe/) {
                         'win32'
                 } else {
                         $shelltype
                 }
         };
  }
  return $shelltype;
}

sub print_environment_vars_for {
  my ($class, $path, $deactivating, $interpolate) = @_;
  print $class->environment_vars_string_for($path, $deactivating, $interpolate);
}

sub environment_vars_string_for {
  my ($class, $path, $deactivating, $interpolate) = @_;
  my @envs = $class->build_environment_vars_for($path, $deactivating, $interpolate);
  my $out = '';

  # rather basic csh detection, goes on the assumption that something won't
  # call itself csh unless it really is. also, default to bourne in the
  # pathological situation where a user doesn't have $ENV{SHELL} defined.
  # note also that shells with funny names, like zoid, are assumed to be
  # bourne.

  my $shelltype = $class->guess_shelltype;

  while (@envs) {
    my ($name, $value) = (shift(@envs), shift(@envs));
    $value =~ s/(\\")/\\$1/g if defined $value;
    $out .= $class->${\"build_${shelltype}_env_declaration"}($name, $value);
  }
  return $out;
}

# simple routines that take two arguments: an %ENV key and a value. return
# strings that are suitable for passing directly to the relevant shell to set
# said key to said value.
sub build_bourne_env_declaration {
  my $class = shift;
  my($name, $value) = @_;
  return defined($value) ? qq{export ${name}="${value}";\n} : qq{unset ${name};\n};
}

sub build_csh_env_declaration {
  my $class = shift;
  my($name, $value) = @_;
  return defined($value) ? qq{setenv ${name} "${value}"\n} : qq{unsetenv ${name}\n};
}

sub build_win32_env_declaration {
  my $class = shift;
  my($name, $value) = @_;
  return defined($value) ? qq{set ${name}=${value}\n} : qq{set ${name}=\n};
}

sub setup_env_hash_for {
  my ($class, $path, $deactivating) = @_;
  my %envs = $class->build_environment_vars_for($path, $deactivating, INTERPOLATE_ENV);
  @ENV{keys %envs} = values %envs;
}

sub build_environment_vars_for {
  my ($class, $path, $deactivating, $interpolate) = @_;

  if ($deactivating == DEACTIVATE_ONE) {
    return $class->build_deactivate_environment_vars_for($path, $interpolate);
  } elsif ($deactivating == DEACTIVATE_ALL) {
    return $class->build_deact_all_environment_vars_for($path, $interpolate);
  } else {
    return $class->build_activate_environment_vars_for($path, $interpolate);
  }
}

sub build_activate_environment_vars_for {
  my ($class, $path, $interpolate) = @_;
  return (
    PERL_LOCAL_LIB_ROOT => join($Config{path_sep},
              (($ENV{PERL_LOCAL_LIB_ROOT}||()) ?
                ($interpolate == INTERPOLATE_ENV
                  ? ($ENV{PERL_LOCAL_LIB_ROOT}||())
                  : (($^O ne 'MSWin32') ? '$PERL_LOCAL_LIB_ROOT' 
                    : '%PERL_LOCAL_LIB_ROOT%' ))
                : ()),
                $path
            ),
    PERL_MB_OPT => "--install_base ${path}",
    PERL_MM_OPT => "INSTALL_BASE=${path}",
    PERL5LIB => join($Config{path_sep},
                  $class->install_base_arch_path($path),
                  $class->install_base_perl_path($path),
                  (($ENV{PERL5LIB}||()) ?
                    ($interpolate == INTERPOLATE_ENV
                      ? ($ENV{PERL5LIB})
                      : (($^O ne 'MSWin32') ? '$PERL5LIB' : '%PERL5LIB%' ))
                    : ())
                ),
    PATH => join($Config{path_sep},
              $class->install_base_bin_path($path),
              ($interpolate == INTERPOLATE_ENV
                ? ($ENV{PATH}||())
                : (($^O ne 'MSWin32') ? '$PATH' : '%PATH%' ))
             ),
  )
}

sub active_paths {
  my ($class) = @_;

  return () unless defined $ENV{PERL_LOCAL_LIB_ROOT};
  return split /\Q$Config{path_sep}/, $ENV{PERL_LOCAL_LIB_ROOT};
}

sub build_deactivate_environment_vars_for {
  my ($class, $path, $interpolate) = @_;

  my @active_lls = $class->active_paths;

  if (!grep { $_ eq $path } @active_lls) {
    warn "Tried to deactivate inactive local::lib '$path'\n";
    return ();
  }

  my @new_ll_root = grep { $_ ne $path } @active_lls;
  my @new_perl5lib = grep {
    $_ ne $class->install_base_arch_path($path) &&
    $_ ne $class->install_base_perl_path($path)
  } split /\Q$Config{path_sep}/, $ENV{PERL5LIB};

  my %env = (
    PERL_LOCAL_LIB_ROOT => (@new_ll_root ?
      join($Config{path_sep}, @new_ll_root) : undef
    ),
    PERL5LIB => (@new_perl5lib ?
      join($Config{path_sep}, @new_perl5lib) : undef
    ),
    PATH => join($Config{path_sep},
      grep { $_ ne $class->install_base_bin_path($path) }
      split /\Q$Config{path_sep}/, $ENV{PATH}
    ),
  );

  # If removing ourselves from the "top of the stack", set install paths to
  # correspond with the new top of stack.
  if ($active_lls[-1] eq $path) {
    if (@active_lls > 1) {
      my $new_top = $active_lls[-2];
      %env = (%env,
        PERL_MB_OPT => "--install_base ${new_top}",
        PERL_MM_OPT => "INSTALL_BASE=${new_top}",
      );
    } else {
      %env = (%env,
        PERL_MB_OPT => undef,
        PERL_MM_OPT => undef,
      );
    }
  }

  return %env;
}

sub build_deact_all_environment_vars_for {
  my ($class, $path, $interpolate) = @_;

  my @active_lls = $class->active_paths;

  my @new_perl5lib = split /\Q$Config{path_sep}/, $ENV{PERL5LIB};
  my @new_path = split /\Q$Config{path_sep}/, $ENV{PATH};

  for my $path (@active_lls) {
    @new_perl5lib = grep {
      $_ ne $class->install_base_arch_path($path) &&
      $_ ne $class->install_base_perl_path($path)
    } @new_perl5lib;

    @new_path = grep {
      $_ ne $class->install_base_bin_path($path)
    } @new_path;
  }

  my %env = (
    PERL_LOCAL_LIB_ROOT => undef,
    PERL_MM_OPT => undef,
    PERL_MB_OPT => undef,
    PERL5LIB => (@new_perl5lib ?
      join($Config{path_sep}, @new_perl5lib) : undef
    ),
    PATH => join($Config{path_sep}, @new_path),
  );

  return %env;
}

1;
