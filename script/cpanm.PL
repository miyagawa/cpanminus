#!/usr/bin/env perl
#
# This is a pre-compiled source code for the cpanm (cpanminus) program.
# For more details about how to install cpanm, go to the following URL:
#
#   https://github.com/miyagawa/cpanminus
#
# Quickstart: Run the following command and it will install itself for
# you. You might want to run it as a root with sudo if you want to install
# to places like /usr/local/bin.
#
#   % curl -L https://cpanmin.us | perl - App::cpanminus
#
# If you don't have curl but wget, replace `curl -L` with `wget -O -`.

# DEVELOPERS: Read maint/build.pl in the repo how to update this
# __FATPACK__

use strict;
use FindBin qw($Bin);                        # For dev -- Auto-removed
use lib "$Bin/../lib", "$Bin/../fatlib"; # For dev -- Auto-removed
use App::cpanminus::script;


unless (caller) {
    my $app = App::cpanminus::script->new;
    $app->parse_options(@ARGV);
    exit $app->doit;
}

__END__

=head1 NAME

cpanm - get, unpack build and install modules from CPAN

=head1 SYNOPSIS

  cpanm Test::More                                 # install Test::More
  cpanm MIYAGAWA/Plack-0.99_05.tar.gz              # full distribution path
  cpanm http://example.org/LDS/CGI.pm-3.20.tar.gz  # install from URL
  cpanm ~/dists/MyCompany-Enterprise-1.00.tar.gz   # install from a local file
  cpanm --interactive Task::Kensho                 # Configure interactively
  cpanm .                                          # install from local directory
  cpanm --installdeps .                            # install all the deps for the current directory
  cpanm -L extlib Plack                            # install Plack and all non-core deps into extlib
  cpanm --mirror http://cpan.cpantesters.org/ DBI  # use the fast-syncing mirror
  cpanm --from https://cpan.metacpan.org/ Plack    # use only the HTTPS mirror

=head1 COMMANDS

=over 4

=item (arguments)

Command line arguments can be either a module name, distribution file,
local file path, HTTP URL or git repository URL. Following commands
will all work as you expect.

    cpanm Plack
    cpanm Plack/Request.pm
    cpanm MIYAGAWA/Plack-1.0000.tar.gz
    cpanm /path/to/Plack-1.0000.tar.gz
    cpanm http://cpan.metacpan.org/authors/id/M/MI/MIYAGAWA/Plack-0.9990.tar.gz
    cpanm git://github.com/plack/Plack.git

Additionally, you can use the notation using C<~> and C<@> to specify
version for a given module. C<~> specifies the version requirement in
the L<CPAN::Meta::Spec> format, while C<@> pins the exact version, and
is a shortcut for C<~"== VERSION">.

    cpanm Plack~1.0000                 # 1.0000 or later
    cpanm Plack~">= 1.0000, < 2.0000"  # latest of 1.xxxx
    cpanm Plack@0.9990                 # specific version. same as Plack~"== 0.9990"

The version query including specific version or range will be sent to
L<MetaCPAN> to search for previous releases. The query will search for
BackPAN archives by default, unless you specify C<--dev> option, in
which case, archived versions will be filtered out.

For a git repository, you can specify a branch, tag, or commit SHA to
build. The default is C<master>

    cpanm git://github.com/plack/Plack.git@1.0000        # tag
    cpanm git://github.com/plack/Plack.git@devel         # branch

=item -i, --install

Installs the modules. This is a default behavior and this is just a
compatibility option to make it work like L<cpan> or L<cpanp>.

=item --self-upgrade

Upgrades itself. It's just an alias for:

  cpanm App::cpanminus

=item --info

Displays the distribution information in
C<AUTHOR/Dist-Name-ver.tar.gz> format in the standard out.

=item --installdeps

Installs the dependencies of the target distribution but won't build
itself. Handy if you want to try the application from a version
controlled repository such as git.

  cpanm --installdeps .

=item --look

Download and unpack the distribution and then open the directory with
your shell. Handy to poke around the source code or do manual
testing.

=item -h, --help

Displays the help message.

=item -V, --version

Displays the version number.

=back

=head1 OPTIONS

You can specify the default options in C<PERL_CPANM_OPT> environment variable.

=over 4

=item -f, --force

Force install modules even when testing failed.

=item -n, --notest

Skip the testing of modules. Use this only when you just want to save
time for installing hundreds of distributions to the same perl and
architecture you've already tested to make sure it builds fine.

Defaults to false, and you can say C<--no-notest> to override when it
is set in the default options in C<PERL_CPANM_OPT>.

=item --test-only

Run the tests only, and do not install the specified module or
distributions. Handy if you want to verify the new (or even old)
releases pass its unit tests without installing the module.

Note that if you specify this option with a module or distribution
that has dependencies, these dependencies will be installed if you
don't currently have them.

=item -S, --sudo

Switch to the root user with C<sudo> when installing modules. Use this
if you want to install modules to the system perl include path.

Defaults to false, and you can say C<--no-sudo> to override when it is
set in the default options in C<PERL_CPANM_OPT>.

=item -v, --verbose

Makes the output verbose. It also enables the interactive
configuration. (See --interactive)

=item -q, --quiet

Makes the output even more quiet than the default. It only shows the
successful/failed dependencies to the output.

=item -l, --local-lib

Sets the L<local::lib> compatible path to install modules to. You
don't need to set this if you already configure the shell environment
variables using L<local::lib>, but this can be used to override that
as well.

=item -L, --local-lib-contained

Same with C<--local-lib> but with L<--self-contained> set.  All
non-core dependencies will be installed even if they're already
installed.

For instance,

  cpanm -L extlib Plack

would install Plack and all of its non-core dependencies into the
directory C<extlib>, which can be loaded from your application with:

  use local::lib '/path/to/extlib';

Note that this option does B<NOT> reliably work with perl installations
supplied by operating system vendors that strips standard modules from perl,
such as RHEL, Fedora and CentOS, B<UNLESS> you also install packages supplying
all the modules that have been stripped.  For these systems you will probably
want to install the C<perl-core> meta-package which does just that.

=item --self-contained

When examining the dependencies, assume no non-core modules are
installed on the system. Handy if you want to bundle application
dependencies in one directory so you can distribute to other machines.

=item --exclude-vendor

Don't include modules installed under the 'vendor' paths when searching for
core modules when the C<--self-contained> flag is in effect.  This restores
the behaviour from before version 1.7023

=item --mirror

Specifies the base URL for the CPAN mirror to use, such as
C<http://cpan.cpantesters.org/> (you can omit the trailing slash). You
can specify multiple mirror URLs by repeating the command line option.

You can use a local directory that has a CPAN mirror structure
(created by tools such as L<OrePAN> or L<Pinto>) by using a special
URL scheme C<file://>. If the given URL begins with `/` (without any
scheme), it is considered as a file scheme as well.

  cpanm --mirror file:///path/to/mirror
  cpanm --mirror ~/minicpan      # Because shell expands ~ to /home/user

Defaults to C<http://www.cpan.org/>.

=item --mirror-only

Download the mirror's 02packages.details.txt.gz index file instead of
querying the CPAN Meta DB. This will also effectively opt out sending
your local perl versions to backend database servers such as CPAN Meta
DB and MetaCPAN.

Select this option if you are using a local mirror of CPAN, such as
minicpan when you're offline, or your own CPAN index (a.k.a darkpan).

=item --from, -M

  cpanm -M https://cpan.metacpan.org/
  cpanm --from https://cpan.metacpan.org/

Use the given mirror URL and its index as the I<only> source to search
and download modules from.

It works similar to C<--mirror> and C<--mirror-only> combined, with a
small difference: unlike C<--mirror> which I<appends> the URL to the
list of mirrors, C<--from> (or C<-M> for short) uses the specified URL
as its I<only> source to download index and modules from. This makes
the option always override the default mirror, which might have been
set via global options such as the one set by C<PERL_CPANM_OPT>
environment variable.

B<Tip:> It might be useful if you name these options with your shell
aliases, like:

  alias minicpanm='cpanm --from ~/minicpan'
  alias darkpan='cpanm --from http://mycompany.example.com/DPAN'

=item --mirror-index

B<EXPERIMENTAL>: Specifies the file path to C<02packages.details.txt>
for module search index.

=item --cpanmetadb

B<EXPERIMENTAL>: Specifies an alternate URI for CPAN MetaDB index lookups.

=item --metacpan

Prefers MetaCPAN API over CPAN MetaDB.

=item --cpanfile

B<EXPERIMENTAL>: Specified an alternate path for cpanfile to search for,
when C<--installdeps> command is in use. Defaults to C<cpanfile>.

=item --prompt

Prompts when a test fails so that you can skip, force install, retry
or look in the shell to see what's going wrong. It also prompts when
one of the dependency failed if you want to proceed the installation.

Defaults to false, and you can say C<--no-prompt> to override if it's
set in the default options in C<PERL_CPANM_OPT>.

=item --dev

B<EXPERIMENTAL>: search for a newer developer release as well. Defaults to false.

=item --reinstall

cpanm, when given a module name in the command line (i.e. C<cpanm
Plack>), checks the locally installed version first and skips if it is
already installed. This option makes it skip the check, so:

  cpanm --reinstall Plack

would reinstall L<Plack> even if your locally installed version is
latest, or even newer (which would happen if you install a developer
release from version control repositories).

Defaults to false.

=item --interactive

Makes the configuration (such as C<Makefile.PL> and C<Build.PL>)
interactive, so you can answer questions in the distribution that
requires custom configuration or Task:: distributions.

Defaults to false, and you can say C<--no-interactive> to override
when it's set in the default options in C<PERL_CPANM_OPT>.

=item --pp, --pureperl

Prefer Pure perl build of modules by setting C<PUREPERL_ONLY=1> for
MakeMaker and C<--pureperl-only> for Build.PL based
distributions. Note that not all of the CPAN modules support this
convention yet.

=item --with-recommends, --with-suggests

B<EXPERIMENTAL>: Installs dependencies declared as C<recommends> and
C<suggests> respectively, per META spec. When these dependencies fail
to install, cpanm continues the installation, since they're just
recommendation/suggestion.

Enabling this could potentially make a circular dependency for a few
modules on CPAN, when C<recommends> adds a module that C<recommends>
back the module in return.

There's also C<--without-recommend> and C<--without-suggests> to
override the default decision made earlier in C<PERL_CPANM_OPT>.

Defaults to false for both.

=item --with-develop

B<EXPERIMENTAL>: Installs develop phase dependencies in META files or
C<cpanfile> when used with C<--installdeps>. Defaults to false.

=item --with-feature, --without-feature, --with-all-features

B<EXPERIMENTAL>: Specifies the feature to enable, if a module supports
optional features per META spec 2.0.

    cpanm --with-feature=opt_csv Spreadsheet::Read

the features can also be interactively chosen when C<--interactive>
option is enabled.

C<--with-all-features> enables all the optional features, and
C<--without-feature> can select a feature to disable.

=item --configure-timeout, --build-timeout, --test-timeout

Specify the timeout length (in seconds) to wait for the configure,
build and test process. Current default values are: 60 for configure,
3600 for build and 1800 for test.

=item --configure-args, --build-args, --test-args, --install-args

B<EXPERIMENTAL>: Pass arguments for configure/build/test/install
commands respectively, for a given module to install.

    cpanm DBD::mysql --configure-args="--cflags=... --libs=..."

The argument is only enabled for the module passed as a command line
argument, not dependencies.

=item --scandeps

B<DEPRECATED>: Scans the depencencies of given modules and output the
tree in a text format. (See C<--format> below for more options)

Because this command doesn't actually install any distributions, it
will be useful that by typing:

  cpanm --scandeps Catalyst::Runtime

you can make sure what modules will be installed.

This command takes into account which modules you already have
installed in your system. If you want to see what modules will be
installed against a vanilla perl installation, you might want to
combine it with C<-L> option.

=item --format

B<DEPRECATED>: Determines what format to display the scanned
dependency tree. Available options are C<tree>, C<json>, C<yaml> and
C<dists>.

=over 8

=item tree

Displays the tree in a plain text format. This is the default value.

=item json, yaml

Outputs the tree in a JSON or YAML format. L<JSON> and L<YAML> modules
need to be installed respectively. The output tree is represented as a
recursive tuple of:

  [ distribution, dependencies ]

and the container is an array containing the root elements. Note that
there may be multiple root nodes, since you can give multiple modules
to the C<--scandeps> command.

=item dists

C<dists> is a special output format, where it prints the distribution
filename in the I<depth first order> after the dependency resolution,
like:

  GAAS/MIME-Base64-3.13.tar.gz
  GAAS/URI-1.58.tar.gz
  PETDANCE/HTML-Tagset-3.20.tar.gz
  GAAS/HTML-Parser-3.68.tar.gz
  GAAS/libwww-perl-5.837.tar.gz

which means you can install these distributions in this order without
extra dependencies. When combined with C<-L> option, it will be useful
to replay installations on other machines.

=back

=item --save-dists

Specifies the optional directory path to copy downloaded tarballs in
the CPAN mirror compatible directory structure
i.e. I<authors/id/A/AU/AUTHORS/Foo-Bar-version.tar.gz>

If the distro tarball did not come from CPAN, for example from a local
file or from GitHub, then it will be saved under
I<vendor/Foo-Bar-version.tar.gz>.

=item --uninst-shadows

Uninstalls the shadow files of the distribution that you're
installing. This eliminates the confusion if you're trying to install
core (dual-life) modules from CPAN against perl 5.10 or older, or
modules that used to be XS-based but switched to pure perl at some
version.

If you run cpanm as root and use C<INSTALL_BASE> or equivalent to
specify custom installation path, you SHOULD disable this option so
you won't accidentally uninstall dual-life modules from the core
include path.

Defaults to true if your perl version is smaller than 5.12, and you
can disable that with C<--no-uninst-shadows>.

B<NOTE>: Since version 1.3000 this flag is turned off by default for
perl newer than 5.12, since with 5.12 @INC contains site_perl directory
I<before> the perl core library path, and uninstalling shadows is not
necessary anymore and does more harm by deleting files from the core
library path.

=item --uninstall, -U

Uninstalls a module from the library path. It finds a packlist for
given modules, and removes all the files included in the same
distribution.

If you enable local::lib, it only removes files from the local::lib
directory.

If you try to uninstall a module in C<perl> directory (i.e. core
module), an error will be thrown.

A dialog will be prompted to confirm the files to be deleted. If you pass
C<-f> option as well, the dialog will be skipped and uninstallation
will be forced.

=item --cascade-search

B<EXPERIMENTAL>: Specifies whether to cascade search when you specify
multiple mirrors and a mirror doesn't have a module or has a lower
version of the module than requested. Defaults to false.

=item --skip-installed

Specifies whether a module given in the command line is skipped if its latest
version is already installed. Defaults to true.

B<NOTE>: The C<PERL5LIB> environment variable have to be correctly set
for this to work with modules installed using L<local::lib>, unless
you always use the C<-l> option.

=item --skip-satisfied

B<EXPERIMENTAL>: Specifies whether a module (and version) given in the
command line is skipped if it's already installed.

If you run:

  cpanm --skip-satisfied CGI DBI~1.2

cpanm won't install them if you already have CGI (for whatever
versions) or have DBI with version higher than 1.2. It is similar to
C<--skip-installed> but while C<--skip-installed> checks if the
I<latest> version of CPAN is installed, C<--skip-satisfied> checks if
a requested version (or not, which means any version) is installed.

Defaults to false.

=item --verify

Verify the integrity of distribution files retrieved from PAUSE using
CHECKSUMS and SIGNATURES (if found). Defaults to false.

=item --report-perl-version

Whether it reports the locally installed perl version to the various
web server as part of User-Agent. Defaults to true unless CI related
environment variables such as C<TRAVIS>, C<CI> or C<AUTOMATED_TESTING>
is enabled. You can disable it by using C<--no-report-perl-version>.

=item --auto-cleanup

Specifies the number of days in which cpanm's work directories
expire. Defaults to 7, which means old work directories will be
cleaned up in one week.

You can set the value to C<0> to make cpan never cleanup those
directories.

=item --man-pages

Generates man pages for executables (man1) and libraries (man3).

Defaults to true (man pages generated) unless C<-L|--local-lib-contained>
option is supplied in which case it's set to false. You can disable
it with C<--no-man-pages>.

=item --lwp

Uses L<LWP> module to download stuff over HTTP. Defaults to true, and
you can say C<--no-lwp> to disable using LWP, when you want to upgrade
LWP from CPAN on some broken perl systems.

=item --wget

Uses GNU Wget (if available) to download stuff. Defaults to true, and
you can say C<--no-wget> to disable using Wget (versions of Wget older
than 1.9 don't support the C<--retry-connrefused> option used by cpanm).

=item --curl

Uses cURL (if available) to download stuff. Defaults to true, and
you can say C<--no-curl> to disable using cURL.

Normally with C<--lwp>, C<--wget> and C<--curl> options set to true
(which is the default) cpanm tries L<LWP>, Wget, cURL and L<HTTP::Tiny>
(in that order) and uses the first one available.

=back

=head1 SEE ALSO

L<App::cpanminus>

=head1 COPYRIGHT

Copyright 2010- Tatsuhiko Miyagawa.

=head1 AUTHOR

Tatsuhiko Miyagawa

=cut
