use strict;
use warnings;

package local::lib;

use 5.008001; # probably works with earlier versions but I'm not supporting them
              # (patches would, of course, be welcome)

use File::Spec ();
use File::Path ();
use Carp ();
use Config;

our $VERSION = '1.004009'; # 1.4.9
my @KNOWN_FLAGS = (qw/--self-contained/);

sub import {
  my ($class, @args) = @_;
  @args <= 1 + @KNOWN_FLAGS or die <<'DEATH';
Please see `perldoc local::lib` for directions on using this module.
DEATH

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
    # The only directories that remain are those that we just defined and those
    # where core modules are stored.  We put PERL5LIB first, so it'll be favored
    # over privlibexp and archlibexp

    @INC = _uniq(
      $class->install_base_arch_path($arg_store{path}),
      $class->install_base_perl_path($arg_store{path}),
      split( $Config{path_sep}, $perl5lib ),
      $Config::Config{archlibexp},
      $Config::Config{privlibexp},
    );

    # We explicitly set PERL5LIB here to the above de-duped list to prevent
    # @INC from growing with each invocation
    $ENV{PERL5LIB} = join( $Config{path_sep}, @INC );
  }

  $arg_store{path} = $class->resolve_path($arg_store{path});
  $class->setup_local_lib_for($arg_store{path});

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
  my ($class, $path) = @_;
  $path = $class->ensure_dir_structure_for($path);
  if ($0 eq '-') {
    $class->print_environment_vars_for($path);
    exit 0;
  } else {
    $class->setup_env_hash_for($path);
    @INC = _uniq(split($Config{path_sep}, $ENV{PERL5LIB}), @INC);
  }
}

sub modulebuildrc_path {
  my ($class, $path) = @_;
  File::Spec->catfile($path, '.modulebuildrc');
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
  my $modulebuildrc_path = $class->modulebuildrc_path($path);
  if (-e $modulebuildrc_path) {
    unless (-f _) {
      Carp::croak("${modulebuildrc_path} exists but is not a plain file");
    }
  } else {
    warn "Attempting to create file ${modulebuildrc_path}\n";
    open MODULEBUILDRC, '>', $modulebuildrc_path
      || Carp::croak("Couldn't open ${modulebuildrc_path} for writing: $!");
    print MODULEBUILDRC qq{install  --install_base  ${path}\n}
      || Carp::croak("Couldn't write line to ${modulebuildrc_path}: $!");
    close MODULEBUILDRC
      || Carp::croak("Couldn't close file ${modulebuildrc_path}: $@");
  }

  return $path;
}

sub INTERPOLATE_ENV () { 1 }
sub LITERAL_ENV     () { 0 }

sub print_environment_vars_for {
  my ($class, $path) = @_;
  my @envs = $class->build_environment_vars_for($path, LITERAL_ENV);
  my $out = '';

  # rather basic csh detection, goes on the assumption that something won't
  # call itself csh unless it really is. also, default to bourne in the
  # pathological situation where a user doesn't have $ENV{SHELL} defined.
  # note also that shells with funny names, like zoid, are assumed to be
  # bourne.
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

  while (@envs) {
    my ($name, $value) = (shift(@envs), shift(@envs));
    $value =~ s/(\\")/\\$1/g;
    $out .= $class->${\"build_${shelltype}_env_declaration"}($name, $value);
  }
  print $out;
}

# simple routines that take two arguments: an %ENV key and a value. return
# strings that are suitable for passing directly to the relevant shell to set
# said key to said value.
sub build_bourne_env_declaration {
  my $class = shift;
  my($name, $value) = @_;
  return qq{export ${name}="${value}"\n};
}

sub build_csh_env_declaration {
  my $class = shift;
  my($name, $value) = @_;
  return qq{setenv ${name} "${value}"\n};
}

sub build_win32_env_declaration {
  my $class = shift;
  my($name, $value) = @_;
  return qq{set ${name}=${value}\n};
}

sub setup_env_hash_for {
  my ($class, $path) = @_;
  my %envs = $class->build_environment_vars_for($path, INTERPOLATE_ENV);
  @ENV{keys %envs} = values %envs;
}

sub build_environment_vars_for {
  my ($class, $path, $interpolate) = @_;
  return (
    MODULEBUILDRC => $class->modulebuildrc_path($path),
    PERL_MM_OPT => "INSTALL_BASE=${path}",
    PERL5LIB => join($Config{path_sep},
                  $class->install_base_perl_path($path),
                  $class->install_base_arch_path($path),
                  ($ENV{PERL5LIB} ?
                    ($interpolate == INTERPOLATE_ENV
                      ? ($ENV{PERL5LIB})
                      : (($^O ne 'MSWin32') ? '$PERL5LIB' : '%PERL5LIB%' ))
                    : ())
                ),
    PATH => join($Config{path_sep},
              $class->install_base_bin_path($path),
              ($interpolate == INTERPOLATE_ENV
                ? $ENV{PATH}
                : (($^O ne 'MSWin32') ? '$PATH' : '%PATH%' ))
             ),
  )
}

=begin testing

#:: test classmethod

File::Path::rmtree('t/var/splat');

$c->ensure_dir_structure_for('t/var/splat');

ok(-d 't/var/splat');

ok(-f 't/var/splat/.modulebuildrc');

=end testing

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

  # Install LWP and it's missing dependencies to the 'my_lwp' directory
  perl -MCPAN -Mlocal::lib=my_lwp -e 'CPAN::install(LWP)'

  # Install LWP and *all non-core* dependencies to the 'my_lwp' directory 
  perl -MCPAN -Mlocal::lib=--self-contained,my_lwp -e 'CPAN::install(LWP)'

  # Just print out useful shell commands
  $ perl -Mlocal::lib
  export MODULEBUILDRC=/home/username/perl/.modulebuildrc
  export PERL_MM_OPT='INSTALL_BASE=/home/username/perl'
  export PERL5LIB='/home/username/perl/lib/perl5:/home/username/perl/lib/perl5/i386-linux'
  export PATH="/home/username/perl/bin:$PATH"

=head2 The bootstrapping technique

A typical way to install local::lib is using what is known as the
"bootstrapping" technique.  You would do this if your system administrator
hasn't already installed local::lib.  In this case, you'll need to install
local::lib in your home directory.

1. Download and unpack the local::lib tarball from CPAN (search for "Download"
on the CPAN page about local::lib).  Do this as an ordinary user, not as root
or administrator.  Unpack the file in your home directory or in any other
convenient location.

2. Run this:

  perl Makefile.PL --bootstrap

If the system asks you whether it should automatically configure as much
as possible, you would typically answer yes.

3. Run this:

  make test && make install

4. Arrange for Perl to use your own packages instead of the system
packages.  If you are using bash, you can do this as follows:

  echo 'eval $(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)' >>~/.bashrc

If you are using C shell, you can do this as follows:

  /bin/csh
  echo $SHELL
  /bin/csh
  perl -I$HOME/perl5/lib/perl5 -Mlocal::lib >> ~/.cshrc

You can also pass --bootstrap=~/foo to get a different location -

  perl Makefile.PL --bootstrap=~/foo
  make test && make install

  echo 'eval $(perl -I$HOME/foo/lib/perl5 -Mlocal::lib=$HOME/foo)' >>~/.bashrc

After writing your shell configuration file, be sure to re-read it to get the
changed settings into your current shell's environment.

  . ~/.bashrc

If you are using C shell, you can do this as follows:

  /bin/csh
  echo $SHELL
  /bin/csh
  perl -I$HOME/perl5/lib/perl5 -Mlocal::lib >> ~/.cshrc

  source ~/.cshrc

You can also pass --bootstrap=~/foo to get a different location -

  perl Makefile.PL --bootstrap=~/foo
  make test && make install

  echo 'eval $(perl -I$HOME/foo/lib/perl5 -Mlocal::lib=$HOME/foo)' >> ~/.bashrc

  . ~/.bashrc

If you're on a slower machine, or are operating under draconian disk space
limitations, you can disable the automatic generation of manpages from POD when
installing modules by using the C<--no-manpages> argument when bootstrapping:

  perl Makefile.PL --bootstrap --no-manpages

If you want to install multiple Perl module environments, say for application evelopment, 
install local::lib globally and then:

  cd ~/mydir1
  perl -Mlocal::lib=./
  eval $(perl -Mlocal::lib=./)  ### To set the environment for this shell alone
  printenv  ### You will see that ~/mydir1 is in the PERL5LIB
  perl -MCPAN -e install ...    ### whatever modules you want
  cd ../mydir2
  ... REPEAT ...

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

  C:\>perl -Mlocal::lib
  set MODULEBUILDRC=C:\DOCUME~1\ADMINI~1\perl5\.modulebuildrc
  set PERL_MM_OPT=INSTALL_BASE=C:\DOCUME~1\ADMINI~1\perl5
  set PERL5LIB=C:\DOCUME~1\ADMINI~1\perl5\lib\perl5;C:\DOCUME~1\ADMINI~1\perl5\lib\perl5\MSWin32-x86-multi-thread
  set PATH=C:\DOCUME~1\ADMINI~1\perl5\bin;%PATH%
  
    ### To set the environment for this shell alone
  C:\>perl -Mlocal::lib > %TEMP%\tmp.bat && %TEMP%\tmp.bat && del %TEMP%\temp.bat
  ### instead of $(perl -Mlocal::lib=./)

If you want the environment entries to persist, you'll need to add then to the
Control Panel's System applet yourself at the moment.

The "~" is translated to the user's profile directory (the directory named for
the user under "Documents and Settings" (Windows XP or earlier) or "Users"
(Windows Vista or later) unless $ENV{HOME} exists. After that, the home
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

=item MODULEBUILDRC

=item PERL_MM_OPT

=item PERL5LIB

=item PATH

PATH is appended to, rather than clobbered.

=back

These values are then available for reference by any code after import.

=head1 METHODS

=head2 ensure_directory_structure_for

=over 4

=item Arguments: path

=back

Attempts to create the given path, and all required parent directories. Throws
an exception on failure.

=head2 print_environment_vars_for

=over 4

=item Arguments: path

=back

Prints to standard output the variables listed above, properly set to use the
given path as the base directory.

=head2 setup_env_hash_for

=over 4

=item Arguments: path

=back

Constructs the C<%ENV> keys for the given path, by calling
C<build_environment_vars_for>.

=head2 install_base_perl_path

=over 4

=item Arguments: path

=back

Returns a path describing where to install the Perl modules for this local
library installation. Appends the directories C<lib> and C<perl5> to the given
path.

=head2 install_base_arch_path

=over 4

=item Arguments: path

=back

Returns a path describing where to install the architecture-specific Perl
modules for this local library installation. Based on the
L</install_base_perl_path> method's return value, and appends the value of
C<$Config{archname}>.

=head2 install_base_bin_path

=over 4

=item Arguments: path

=back

Returns a path describing where to install the executable programs for this
local library installation. Based on the L</install_base_perl_path> method's
return value, and appends the directory C<bin>.

=head2 modulebuildrc_path

=over 4

=item Arguments: path

=back

Returns a path describing where to install the C<.modulebuildrc> file, based on
the given path.

=head2 resolve_empty_path

=over 4

=item Arguments: path

=back

Builds and returns the base path into which to set up the local module
installation. Defaults to C<~/perl5>.

=head2 resolve_home_path

=over 4

=item Arguments: path

=back

Attempts to find the user's home directory. If installed, uses C<File::HomeDir>
for this purpose. If no definite answer is available, throws an exception.

=head2 resolve_relative_path

=over 4

=item Arguments: path

=back

Translates the given path into an absolute path.

=head2 resolve_path

=over 4

=item Arguments: path

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

Rather basic shell detection. Right now anything with csh in its name is
assumed to be a C shell or something compatible, and everything else is assumed
to be Bourne, except on Win32 systems. If the C<SHELL> environment variable is
not set, a Bourne-compatible shell is assumed.

Bootstrap is a hack and will use CPAN.pm for ExtUtils::MakeMaker even if you
have CPANPLUS installed.

Kills any existing PERL5LIB, PERL_MM_OPT or MODULEBUILDRC.

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

=head1 AUTHOR

Matt S Trout <mst@shadowcat.co.uk> http://www.shadowcat.co.uk/

auto_install fixes kindly sponsored by http://www.takkle.com/

=head1 CONTRIBUTORS

Chris Nehren <apeiron@cpan.org> now oversees maintenance of local::lib, in
addition to providing doc patches and bootstrap fixes to prevent users from
shooting themselves in the foot (it's more likely than you think).

Patches to correctly output commands for csh style shells, as well as some
documentation additions, contributed by Christopher Nehren <apeiron@cpan.org>.

'--self-contained' feature contributed by Mark Stosberg <mark@summersault.com>.

Ability to pass '--self-contained' without a directory inspired by frew on
irc.perl.org/#catalyst.

Doc patches for a custom local::lib directory contributed by Torsten Raudssus
<torsten@raudssus.de>.

Hans Dieter Pearcey <hdp@cpan.org> sent in some additional tests for ensuring
things will install properly, submitted a fix for the bug causing problems with
writing Makefiles during bootstrapping, contributed an example program, and
submitted yet another fix to ensure that local::lib can install and bootstrap
properly. Many, many thanks!

pattern of Freenode IRC contributed the beginnings of the Troubleshooting
section. Many thanks!

Patch to add Win32 support contributed by Curtis Jewell <csjewell@cpan.org>.

kgish/#perl-help@irc.perl.org suggested revamping the section on sourcing the
shell file to make it clearer to those quickly reading the POD.

t0m and chrisa on #local-lib@irc.perl.org pointed out a PERL5LIB ordering issue
with C<--self-contained>.

=head1 COPYRIGHT

Copyright (c) 2007 - 2009 the local::lib L</AUTHOR> and L</CONTRIBUTORS> as
listed above.

=head1 LICENSE

This library is free software and may be distributed under the same terms
as perl itself.

=cut

1;
