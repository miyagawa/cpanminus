#!/usr/bin/env perl
#
# You want to install cpanminus? Run the following command and it will
# install itself for you. You might want to run it as a root with sudo
# if you want to install to places like /usr/local/bin.
#
#   % curl -L http://cpanmin.us | perl - --self-upgrade
#
# If you don't have curl but wget, replace `curl -L` with `wget -O -`.
#
# For more details about this program, visit http://search.cpan.org/dist/App-cpanminus
#
# DEVELOPERS: Read script/build.PL in the repo how to update this
# __FATPACK__
use strict;
use FindBin qw($Bin);                    # For dev -- Auto-removed
use lib "$Bin/../lib", "$Bin/../fatlib"; # For dev -- Auto-removed
use App::cpanminus::script;

unless (caller) {
    my $app = App::cpanminus::script->new;
    $app->parse_options(@ARGV);
    $app->doit or exit(1);
}

__END__

=head1 NAME

cpanm - get, unpack build and install modules from CPAN

=head1 SYNOPSIS

  cpanm Test::More                                          # install Test::More
  cpanm MIYAGAWA/Plack-0.99_05.tar.gz                       # full distribution path
  cpanm http://example.org/LDS/CGI.pm-3.20.tar.gz           # install from URL
  cpanm ~/dists/MyCompany-Enterprise-1.00.tar.gz            # install from a local file
  cpanm --interactive Task::Kensho                          # Configure interactively
  cpanm .                                                   # install from local directory
  cpanm --installdeps .                                     # install all the deps for the current directory
  cpanm -L extlib Plack                                     # install Plack and all non-core deps into extlib
  cpanm --mirror http://cpan.cpantesters.org/ DBI           # use the fast-syncing mirror

=head1 COMMANDS

=over 4

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
your shell. Handy to poke around the source code or do the manual
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

Defaults to false, and you can say C<--no-force> to override when it
is set in the default options in C<PERL_CPANM_OPT>.

=item -n, --notest

Skip the testing of modules. Use this only when you just want to save
time for installing hundreds of distributions to the same perl and
architecture you've already tested to make sure it builds fine.

Defaults to false, and you can say C<--no-notest> to override when it
is set in the default options in C<PERL_CPANM_OPT>.

=item -S, --sudo

Switch to the root user with C<sudo> when installing modules. Use this
if you want to install modules to the system perl include path.

Defaults to false, and you can say C<--no-sudo> to override when it is
set in the default options in C<PERL_CPANM_OPT>.

=item -v, --verbose

Makes the output verbose. It also enables the interactive
configuration. (See --interactive)

=item -q, --quiet

Makes the output even more quiet than the default. It doesn't print
anything to the STDERR.

=item -l, --local-lib

Sets the L<local::lib> compatible path to install modules to. You
don't need to set this if you already configure the shell environment
variables using L<local::lib>, but this can be used to override that
as well.

=item -L, --local-lib-contained

Same with C<--local-lib> but when examining the dependencies, it
assumes no non-core modules are installed on the system. It's handy if
you want to bundle application dependencies in one directory so you
can distribute to other machines.

For instance,

  cpanm -L extlib Plack

would install Plack and all of its non-core dependencies into the
directory C<extlib>, which can be loaded from your application with:

  use local::lib '/path/to/extlib';

=item --mirror

Specifies the base URL for the CPAN mirror to use, such as
C<http://cpan.cpantesters.org/> (you can omit the trailing slash). You
can specify multiple mirror URLs by repeating the command line option.

Defaults to C<http://search.cpan.org/CPAN> which is a geo location
aware redirector.

=item --prompt

Prompts when a test fails so that you can skip, force install, retry
or look in the shell to see what's going wrong. It also prompts when
one of the dependency failed if you want to proceed the installation.

Defaults to false, and you can say C<--no-prompt> to override if it's
set in the default options in C<PERL_CPANM_OPT>.

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

Defaults to true, and you can disable that with
C<--no-uninst-shadows>.

=item --lwp

Uses L<LWP> module to download stuff over HTTP. Defaults to true, and
you can say C<--no-lwp> to disable using LWP, when you want to upgrade
LWP from CPAN on some broken perl systems.

=back

=head1 SEE ALSO

L<App::cpanminus>

=head1 COPYRIGHT

Copyright 2010 Tatsuhiko Miyagawa.

=head1 AUTHOR

Tatsuhiko Miyagawa

=cut
