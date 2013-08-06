use strict;
use warnings;

package local::lib;

use 5.008001; # probably works with earlier versions but I'm not supporting them
              # (patches would, of course, be welcome)

use File::Spec ();
use File::Path ();
use Config;

our $VERSION = '1.008011'; # 1.8.11

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

=begin testing

#:: test pipeline

package local::lib;

{ package Foo; sub foo { -$_[1] } sub bar { $_[1]+2 } sub baz { $_[1]+3 } }
my $foo = bless({}, 'Foo');                                                 
Test::More::ok($foo->${pipeline qw(foo bar baz)}(10) == -15);

=end testing

=cut

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

=begin testing

#:: test classmethod setup

my $c = 'local::lib';

=end testing

=begin testing

#:: test classmethod

is($c->resolve_empty_path, '~/perl5');
is($c->resolve_empty_path('foo'), 'foo');

=end testing

=cut

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

=begin testing

#:: test classmethod

local *File::Spec::rel2abs = sub { shift; 'FOO'.shift; };
is($c->resolve_relative_path('bar'),'FOObar');

=end testing

=cut

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
        defined $ENV{${$_}} ? (split /\Q$Config{path_sep}/, $ENV{${$_}}) : ()
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

=begin testing

#:: test classmethod

File::Path::rmtree('t/var/splat');

$c->ensure_dir_structure_for('t/var/splat');

ok(-d 't/var/splat');

=end testing

=encoding utf8

=head1 NAME

local::lib - create and use a local lib/ for perl modules with PERL5LIB

=head1 SYNOPSIS

In code -

  use local::lib; # sets up a local lib at ~/perl5

  use local::lib '~/foo'; # same, but ~/foo

  # Or...
  use FindBin;
  use local::lib "$FindBin::Bin/../support";  # app-local support library

From the shell -

  # Install LWP and its missing dependencies to the '~/perl5' directory
  perl -MCPAN -Mlocal::lib -e 'CPAN::install(LWP)'

  # Just print out useful shell commands
  $ perl -Mlocal::lib
  export PERL_MB_OPT='--install_base /home/username/perl5'
  export PERL_MM_OPT='INSTALL_BASE=/home/username/perl5'
  export PERL5LIB='/home/username/perl5/lib/perl5/i386-linux:/home/username/perl5/lib/perl5'
  export PATH="/home/username/perl5/bin:$PATH"

=head2 The bootstrapping technique

A typical way to install local::lib is using what is known as the
"bootstrapping" technique.  You would do this if your system administrator
hasn't already installed local::lib.  In this case, you'll need to install
local::lib in your home directory. 

If you do have administrative privileges, you will still want to set up your 
environment variables, as discussed in step 4. Without this, you would still
install the modules into the system CPAN installation and also your Perl scripts
will not use the lib/ path you bootstrapped with local::lib.

By default local::lib installs itself and the CPAN modules into ~/perl5.

Windows users must also see L</Differences when using this module under Win32>.

1. Download and unpack the local::lib tarball from CPAN (search for "Download"
on the CPAN page about local::lib).  Do this as an ordinary user, not as root
or administrator.  Unpack the file in your home directory or in any other
convenient location.

2. Run this:

  perl Makefile.PL --bootstrap

If the system asks you whether it should automatically configure as much
as possible, you would typically answer yes.

In order to install local::lib into a directory other than the default, you need
to specify the name of the directory when you call bootstrap, as follows:

  perl Makefile.PL --bootstrap=~/foo

3. Run this: (local::lib assumes you have make installed on your system)

  make test && make install

4. Now we need to setup the appropriate environment variables, so that Perl 
starts using our newly generated lib/ directory. If you are using bash or
any other Bourne shells, you can add this to your shell startup script this
way:

  echo 'eval $(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)' >>~/.bashrc

If you are using C shell, you can do this as follows:

  /bin/csh
  echo $SHELL
  /bin/csh
  perl -I$HOME/perl5/lib/perl5 -Mlocal::lib >> ~/.cshrc

If you passed to bootstrap a directory other than default, you also need to give that as 
import parameter to the call of the local::lib module like this way:

  echo 'eval $(perl -I$HOME/foo/lib/perl5 -Mlocal::lib=$HOME/foo)' >>~/.bashrc

After writing your shell configuration file, be sure to re-read it to get the
changed settings into your current shell's environment. Bourne shells use 
C<. ~/.bashrc> for this, whereas C shells use C<source ~/.cshrc>.

If you're on a slower machine, or are operating under draconian disk space
limitations, you can disable the automatic generation of manpages from POD when
installing modules by using the C<--no-manpages> argument when bootstrapping:

  perl Makefile.PL --bootstrap --no-manpages

To avoid doing several bootstrap for several Perl module environments on the 
same account, for example if you use it for several different deployed 
applications independently, you can use one bootstrapped local::lib 
installation to install modules in different directories directly this way:

  cd ~/mydir1
  perl -Mlocal::lib=./
  eval $(perl -Mlocal::lib=./)  ### To set the environment for this shell alone
  printenv                      ### You will see that ~/mydir1 is in the PERL5LIB
  perl -MCPAN -e install ...    ### whatever modules you want
  cd ../mydir2
  ... REPEAT ...

If you are working with several C<local::lib> environments, you may want to
remove some of them from the current environment without disturbing the others.
You can deactivate one environment like this (using bourne sh):

  eval $(perl -Mlocal::lib=--deactivate,~/path)

which will generate and run the commands needed to remove C<~/path> from your
various search paths. Whichever environment was B<activated most recently> will
remain the target for module installations. That is, if you activate
C<~/path_A> and then you activate C<~/path_B>, new modules you install will go
in C<~/path_B>. If you deactivate C<~/path_B> then modules will be installed
into C<~/pathA> -- but if you deactivate C<~/path_A> then they will still be
installed in C<~/pathB> because pathB was activated later.

You can also ask C<local::lib> to clean itself completely out of the current
shell's environment with the C<--deactivate-all> option.
For multiple environments for multiple apps you may need to include a modified
version of the C<< use FindBin >> instructions in the "In code" sample above.
If you did something like the above, you have a set of Perl modules at C<<
~/mydir1/lib >>. If you have a script at C<< ~/mydir1/scripts/myscript.pl >>,
you need to tell it where to find the modules you installed for it at C<<
~/mydir1/lib >>.

In C<< ~/mydir1/scripts/myscript.pl >>:

  use strict;
  use warnings;
  use local::lib "$FindBin::Bin/..";  ### points to ~/mydir1 and local::lib finds lib
  use lib "$FindBin::Bin/../lib";     ### points to ~/mydir1/lib

Put this before any BEGIN { ... } blocks that require the modules you installed.

=head2 Differences when using this module under Win32

To set up the proper environment variables for your current session of
C<CMD.exe>, you can use this:

  C:\>perl -Mlocal::lib
  set PERL_MB_OPT=--install_base C:\DOCUME~1\ADMINI~1\perl5
  set PERL_MM_OPT=INSTALL_BASE=C:\DOCUME~1\ADMINI~1\perl5
  set PERL5LIB=C:\DOCUME~1\ADMINI~1\perl5\lib\perl5;C:\DOCUME~1\ADMINI~1\perl5\lib\perl5\MSWin32-x86-multi-thread
  set PATH=C:\DOCUME~1\ADMINI~1\perl5\bin;%PATH%
  
  ### To set the environment for this shell alone
  C:\>perl -Mlocal::lib > %TEMP%\tmp.bat && %TEMP%\tmp.bat && del %TEMP%\tmp.bat
  ### instead of $(perl -Mlocal::lib=./)

If you want the environment entries to persist, you'll need to add then to the
Control Panel's System applet yourself or use L<App::local::lib::Win32Helper>.

The "~" is translated to the user's profile directory (the directory named for
the user under "Documents and Settings" (Windows XP or earlier) or "Users"
(Windows Vista or later)) unless $ENV{HOME} exists. After that, the home
directory is translated to a short name (which means the directory must exist)
and the subdirectories are created.

=head1 RATIONALE

The version of a Perl package on your machine is not always the version you
need.  Obviously, the best thing to do would be to update to the version you
need.  However, you might be in a situation where you're prevented from doing
this.  Perhaps you don't have system administrator privileges; or perhaps you
are using a package management system such as Debian, and nobody has yet gotten
around to packaging up the version you need.

local::lib solves this problem by allowing you to create your own directory of
Perl packages downloaded from CPAN (in a multi-user system, this would typically
be within your own home directory).  The existing system Perl installation is
not affected; you simply invoke Perl with special options so that Perl uses the
packages in your own local package directory rather than the system packages.
local::lib arranges things so that your locally installed version of the Perl
packages takes precedence over the system installation.

If you are using a package management system (such as Debian), you don't need to
worry about Debian and CPAN stepping on each other's toes.  Your local version
of the packages will be written to an entirely separate directory from those
installed by Debian.  

=head1 DESCRIPTION

This module provides a quick, convenient way of bootstrapping a user-local Perl
module library located within the user's home directory. It also constructs and
prints out for the user the list of environment variables using the syntax
appropriate for the user's current shell (as specified by the C<SHELL>
environment variable), suitable for directly adding to one's shell
configuration file.

More generally, local::lib allows for the bootstrapping and usage of a
directory containing Perl modules outside of Perl's C<@INC>. This makes it
easier to ship an application with an app-specific copy of a Perl module, or
collection of modules. Useful in cases like when an upstream maintainer hasn't
applied a patch to a module of theirs that you need for your application.

On import, local::lib sets the following environment variables to appropriate
values:

=over 4

=item PERL_MB_OPT

=item PERL_MM_OPT

=item PERL5LIB

=item PATH

PATH is appended to, rather than clobbered.

=back

These values are then available for reference by any code after import.

=head1 CREATING A SELF-CONTAINED SET OF MODULES

See L<lib::core::only> for one way to do this - but note that
there are a number of caveats, and the best approach is always to perform a
build against a clean perl (i.e. site and vendor as close to empty as possible).

=head1 OPTIONS

Options are values that can be passed to the C<local::lib> import besides the
directory to use. They are specified as C<use local::lib '--option'[, path];>
or C<perl -Mlocal::lib=--option[,path]>.

=head2 --deactivate

Remove the chosen path (or the default path) from the module search paths if it
was added by C<local::lib>, instead of adding it.

=head2 --deactivate-all

Remove all directories that were added to search paths by C<local::lib> from the
search paths.

=head1 METHODS

=head2 ensure_dir_structure_for

=over 4

=item Arguments: $path

=item Return value: None

=back

Attempts to create the given path, and all required parent directories. Throws
an exception on failure.

=head2 print_environment_vars_for

=over 4

=item Arguments: $path

=item Return value: None

=back

Prints to standard output the variables listed above, properly set to use the
given path as the base directory.

=head2 build_environment_vars_for

=over 4

=item Arguments: $path, $interpolate

=item Return value: \%environment_vars

=back

Returns a hash with the variables listed above, properly set to use the
given path as the base directory.

=head2 setup_env_hash_for

=over 4

=item Arguments: $path

=item Return value: None

=back

Constructs the C<%ENV> keys for the given path, by calling
L</build_environment_vars_for>.

=head2 active_paths

=over 4

=item Arguments: None

=item Return value: @paths

=back

Returns a list of active C<local::lib> paths, according to the
C<PERL_LOCAL_LIB_ROOT> environment variable.

=head2 install_base_perl_path

=over 4

=item Arguments: $path

=item Return value: $install_base_perl_path

=back

Returns a path describing where to install the Perl modules for this local
library installation. Appends the directories C<lib> and C<perl5> to the given
path.

=head2 install_base_arch_path

=over 4

=item Arguments: $path

=item Return value: $install_base_arch_path

=back

Returns a path describing where to install the architecture-specific Perl
modules for this local library installation. Based on the
L</install_base_perl_path> method's return value, and appends the value of
C<$Config{archname}>.

=head2 install_base_bin_path

=over 4

=item Arguments: $path

=item Return value: $install_base_bin_path

=back

Returns a path describing where to install the executable programs for this
local library installation. Based on the L</install_base_perl_path> method's
return value, and appends the directory C<bin>.

=head2 resolve_empty_path

=over 4

=item Arguments: $path

=item Return value: $base_path

=back

Builds and returns the base path into which to set up the local module
installation. Defaults to C<~/perl5>.

=head2 resolve_home_path

=over 4

=item Arguments: $path

=item Return value: $home_path

=back

Attempts to find the user's home directory. If installed, uses C<File::HomeDir>
for this purpose. If no definite answer is available, throws an exception.

=head2 resolve_relative_path

=over 4

=item Arguments: $path

=item Return value: $absolute_path

=back

Translates the given path into an absolute path.

=head2 resolve_path

=over 4

=item Arguments: $path

=item Return value: $absolute_path

=back

Calls the following in a pipeline, passing the result from the previous to the
next, in an attempt to find where to configure the environment for a local
library installation: L</resolve_empty_path>, L</resolve_home_path>,
L</resolve_relative_path>. Passes the given path argument to
L</resolve_empty_path> which then returns a result that is passed to
L</resolve_home_path>, which then has its result passed to
L</resolve_relative_path>. The result of this final call is returned from
L</resolve_path>.

=head1 A WARNING ABOUT UNINST=1

Be careful about using local::lib in combination with "make install UNINST=1".
The idea of this feature is that will uninstall an old version of a module
before installing a new one. However it lacks a safety check that the old
version and the new version will go in the same directory. Used in combination
with local::lib, you can potentially delete a globally accessible version of a
module while installing the new version in a local place. Only combine "make
install UNINST=1" and local::lib if you understand these possible consequences.

=head1 LIMITATIONS

The perl toolchain is unable to handle directory names with spaces in it,
so you cant put your local::lib bootstrap into a directory with spaces. What
you can do is moving your local::lib to a directory with spaces B<after> you
installed all modules inside your local::lib bootstrap. But be aware that you
cant update or install CPAN modules after the move.

Rather basic shell detection. Right now anything with csh in its name is
assumed to be a C shell or something compatible, and everything else is assumed
to be Bourne, except on Win32 systems. If the C<SHELL> environment variable is
not set, a Bourne-compatible shell is assumed.

Bootstrap is a hack and will use CPAN.pm for ExtUtils::MakeMaker even if you
have CPANPLUS installed.

Kills any existing PERL5LIB, PERL_MM_OPT or PERL_MB_OPT.

Should probably auto-fixup CPAN config if not already done.

Patches very much welcome for any of the above.

On Win32 systems, does not have a way to write the created environment variables
to the registry, so that they can persist through a reboot.

=head1 TROUBLESHOOTING

If you've configured local::lib to install CPAN modules somewhere in to your
home directory, and at some point later you try to install a module with C<cpan
-i Foo::Bar>, but it fails with an error like: C<Warning: You do not have
permissions to install into /usr/lib64/perl5/site_perl/5.8.8/x86_64-linux at
/usr/lib64/perl5/5.8.8/Foo/Bar.pm> and buried within the install log is an
error saying C<'INSTALL_BASE' is not a known MakeMaker parameter name>, then
you've somehow lost your updated ExtUtils::MakeMaker module.

To remedy this situation, rerun the bootstrapping procedure documented above.

Then, run C<rm -r ~/.cpan/build/Foo-Bar*>

Finally, re-run C<cpan -i Foo::Bar> and it should install without problems.

=head1 ENVIRONMENT

=over 4

=item SHELL

=item COMSPEC

local::lib looks at the user's C<SHELL> environment variable when printing out
commands to add to the shell configuration file.

On Win32 systems, C<COMSPEC> is also examined.

=back

=head1 SEE ALSO

=over 4

=item * L<Perl Advent article, 2011|http://perladvent.org/2011/2011-12-01.html>

=back

=head1 SUPPORT

IRC:

    Join #local-lib on irc.perl.org.

=head1 AUTHOR

Matt S Trout <mst@shadowcat.co.uk> http://www.shadowcat.co.uk/

auto_install fixes kindly sponsored by http://www.takkle.com/

=head1 CONTRIBUTORS

Patches to correctly output commands for csh style shells, as well as some
documentation additions, contributed by Christopher Nehren <apeiron@cpan.org>.

Doc patches for a custom local::lib directory, more cleanups in the english
documentation and a L<german documentation|POD2::DE::local::lib> contributed by Torsten Raudssus
<torsten@raudssus.de>.

Hans Dieter Pearcey <hdp@cpan.org> sent in some additional tests for ensuring
things will install properly, submitted a fix for the bug causing problems with
writing Makefiles during bootstrapping, contributed an example program, and
submitted yet another fix to ensure that local::lib can install and bootstrap
properly. Many, many thanks!

pattern of Freenode IRC contributed the beginnings of the Troubleshooting
section. Many thanks!

Patch to add Win32 support contributed by Curtis Jewell <csjewell@cpan.org>.

Warnings for missing PATH/PERL5LIB (as when not running interactively) silenced
by a patch from Marco Emilio Poleggi.

Mark Stosberg <mark@summersault.com> provided the code for the now deleted
'--self-contained' option.

Documentation patches to make win32 usage clearer by
David Mertens <dcmertens.perl@gmail.com> (run4flat).

Brazilian L<portuguese translation|POD2::PT_BR::local::lib> and minor doc patches contributed by Breno
G. de Oliveira <garu@cpan.org>.

Improvements to stacking multiple local::lib dirs and removing them from the
environment later on contributed by Andrew Rodland <arodland@cpan.org>.

Patch for Carp version mismatch contributed by Hakim Cassimally <osfameron@cpan.org>.

=head1 COPYRIGHT

Copyright (c) 2007 - 2010 the local::lib L</AUTHOR> and L</CONTRIBUTORS> as
listed above.

=head1 LICENSE

This library is free software and may be distributed under the same terms
as perl itself.

=cut

1;
