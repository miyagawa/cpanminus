use strict;
use warnings;

package local::lib;

use 5.008001; # probably works with earlier versions but I'm not supporting them
              # (patches would, of course, be welcome)

use File::Spec ();
use File::Path ();
use Config;

our $VERSION = '1.008009'; # 1.8.9

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
    require Carp;
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

  $class->ensure_dir_structure_for($path);

  # On Win32 directories often contain spaces. But some parts of the CPAN
  # toolchain don't like that. To avoid this, GetShortPathName() gives us
  # an alternate representation that has none.
  # This only works if the directory already exists.
  $path = Win32::GetShortPathName($path) if $^O eq 'MSWin32';

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
    my $arch_dir = $Config{archname};
    @INC = _uniq(
  (
      # Inject $path/$archname for each path in PERL5LIB
      map { ( File::Spec->catdir($_, $arch_dir), $_ ) }
      split($Config{path_sep}, $ENV{PERL5LIB})
  ),
  @INC
    );
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
  return
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

# Build an environment value for a variable like PATH from a list of paths.
# References to existing variables are given as references to the variable name.
# Duplicates are removed.
#
# options:
# - interpolate: INTERPOLATE_ENV/LITERAL_ENV
# - exists: paths are included only if they exist (default: interpolate == INTERPOLATE_ENV)
# - filter: function to apply to each path do decide if it must be included
# - empty: the value to return in the case of empty value
my %ENV_LIST_VALUE_DEFAULTS = (
    interpolate => INTERPOLATE_ENV,
    exists => undef,
    filter => sub { 1 },
    empty => undef,
);
sub _env_list_value {
  my $options = shift;
  die(sprintf "unknown option '$_' at %s line %u\n", (caller)[1..2])
    for grep { !exists $ENV_LIST_VALUE_DEFAULTS{$_} } keys %$options;
  my %options = (%ENV_LIST_VALUE_DEFAULTS, %{ $options });
  $options{exists} = $options{interpolate} == INTERPOLATE_ENV
    unless defined $options{exists};

  my %seen;

  my $value = join($Config{path_sep}, map {
      ref $_ ? ($^O eq 'MSWin32' ? "%${$_}%" : "\$${$_}") : $_
    } grep {
      ref $_ || (defined $_
                 && length($_) > 0
                 && !$seen{$_}++
                 && $options{filter}->($_)
                 && (!$options{exists} || -e $_))
    } map {
      if (ref $_ eq 'SCALAR' && $options{interpolate} == INTERPOLATE_ENV) {
        exists $ENV{${$_}} ? (split /\Q$Config{path_sep}/, $ENV{${$_}}) : ()
      } else {
        $_
      }
    } @_);
  return length($value) ? $value : $options{empty};
}

sub build_activate_environment_vars_for {
  my ($class, $path, $interpolate) = @_;
  return (
    PERL_LOCAL_LIB_ROOT =>
            _env_list_value(
              { interpolate => $interpolate, exists => 0, empty => '' },
              \'PERL_LOCAL_LIB_ROOT',
              $path,
            ),
    PERL_MB_OPT => "--install_base ${path}",
    PERL_MM_OPT => "INSTALL_BASE=${path}",
    PERL5LIB =>
            _env_list_value(
              { interpolate => $interpolate, exists => 0, empty => '' },
              $class->install_base_perl_path($path),
              \'PERL5LIB',
            ),
    PATH => _env_list_value(
              { interpolate => $interpolate, exists => 0, empty => '' },
        $class->install_base_bin_path($path),
              \'PATH',
            ),
  )
}

sub active_paths {
  my ($class) = @_;

  return () unless defined $ENV{PERL_LOCAL_LIB_ROOT};
  return grep { $_ ne '' } split /\Q$Config{path_sep}/, $ENV{PERL_LOCAL_LIB_ROOT};
}

sub build_deactivate_environment_vars_for {
  my ($class, $path, $interpolate) = @_;

  my @active_lls = $class->active_paths;

  if (!grep { $_ eq $path } @active_lls) {
    warn "Tried to deactivate inactive local::lib '$path'\n";
    return ();
  }

  my $perl_path = $class->install_base_perl_path($path);
  my $arch_path = $class->install_base_arch_path($path);
  my $bin_path = $class->install_base_bin_path($path);


  my %env = (
    PERL_LOCAL_LIB_ROOT => _env_list_value(
      {
        exists => 0,
      },
      grep { $_ ne $path } @active_lls
    ),
    PERL5LIB => _env_list_value(
      {
        exists => 0,
        filter => sub {
          $_ ne $perl_path && $_ ne $arch_path
        },
      },
      \'PERL5LIB',
    ),
    PATH => _env_list_value(
      {
        exists => 0,
        filter => sub { $_ ne $bin_path },
      },
      \'PATH',
    ),
  );

  # If removing ourselves from the "top of the stack", set install paths to
  # correspond with the new top of stack.
  if ($active_lls[-1] eq $path) {
    my $new_top = $active_lls[-2];
    $env{PERL_MB_OPT} = defined($new_top) ? "--install_base ${new_top}" : undef;
    $env{PERL_MM_OPT} = defined($new_top) ? "INSTALL_BASE=${new_top}" : undef;
  }

  return %env;
}

sub build_deact_all_environment_vars_for {
  my ($class, $path, $interpolate) = @_;

  my @active_lls = $class->active_paths;

  my %perl_paths = map { (
      $class->install_base_perl_path($_) => 1,
      $class->install_base_arch_path($_) => 1
    ) } @active_lls;
  my %bin_paths = map { (
      $class->install_base_bin_path($_) => 1,
    ) } @active_lls;

  my %env = (
    PERL_LOCAL_LIB_ROOT => undef,
    PERL_MM_OPT => undef,
    PERL_MB_OPT => undef,
    PERL5LIB => _env_list_value(
      {
        exists => 0,
        filter => sub {
          ! scalar grep { exists $perl_paths{$_} } $_[0]
        },
      },
      \'PERL5LIB'
    ),
    PATH => _env_list_value(
      {
        exists => 0,
        filter => sub {
          ! scalar grep { exists $bin_paths{$_} } $_[0]
        },
      },
      \'PATH'
    ),
  );

  return %env;
}

1;
