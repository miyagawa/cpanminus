package App::cpanminus;
our $VERSION = "1.6005";

=head1 NAME

App::cpanminus - get, unpack, build and install modules from CPAN

=head1 SYNOPSIS

    cpanm Module

Run C<cpanm -h> or C<perldoc cpanm> for more options.

=head1 DESCRIPTION

cpanminus is a script to get, unpack, build and install modules from
CPAN and does nothing else.

It's dependency free (can bootstrap itself), requires zero
configuration, and stands alone. When running, it requires only 10MB
of RAM.

=head1 INSTALLATION

There are several ways to install cpanminus to your system.

=head2 Package management system

There are Debian packages, RPMs, FreeBSD ports, and packages for other
operation systems available. If you want to use the package management system,
search for cpanminus and use the appropriate command to install. This makes it
easy to install C<cpanm> to your system without thinking about where to
install, and later upgrade.

=head2 Installing to system perl

You can also use the latest cpanminus to install cpanminus itself:

    curl -L http://cpanmin.us | perl - --sudo App::cpanminus

This will install C<cpanm> to your bin directory like
C</usr/local/bin> (unless you configured C<INSTALL_BASE> with
L<local::lib>), so you probably need the C<--sudo> option.

=head2 Installing to local perl (perlbrew)

If you have perl in your home directory, which is the case if you use
tools like L<perlbrew>, you don't need the C<--sudo> option, since
you're most likely to have a write permission to the perl's library
path. You can just do:

    curl -L http://cpanmin.us | perl - App::cpanminus

to install the C<cpanm> executable to the perl's bin path, like
C<~/perl5/perlbrew/bin/cpanm>.

=head2 Downloading the standalone executable

You can also copy the standalone executable to whatever location you'd like.

    cd ~/bin
    curl -LO http://xrl.us/cpanm
    chmod +x cpanm
    # edit shebang if you don't have /usr/bin/env

This just works, but be sure to grab the new version manually when you
upgrade because C<--self-upgrade> might not work for this.

=head1 DEPENDENCIES

perl 5.8 or later.

=over 4

=item *

'tar' executable (bsdtar or GNU tar version 1.22 are rcommended) or Archive::Tar to unpack files.

=item *

C compiler, if you want to build XS modules.

=item *

make

=item *

Module::Build (core in 5.10)

=back

=head1 QUESTIONS

=head2 Another CPAN installer?

OK, the first motivation was this: the CPAN shell runs out of memory (or swaps
heavily and gets really slow) on Slicehost/linode's most affordable plan with
only 256MB RAM. Should I pay more to install perl modules from CPAN? I don't
think so.

=head2 But why a new client?

First of all, let me be clear that CPAN and CPANPLUS are great tools
I've used for I<literally> years (you know how many modules I have on
CPAN, right?). I really respect their efforts of maintaining the most
important tools in the CPAN toolchain ecosystem.

However, for less experienced users (mostly from outside the Perl community),
or even really experienced Perl developers who know how to shoot themselves in
their feet, setting up the CPAN toolchain often feels like yak shaving,
especially when all they want to do is just install some modules and start
writing code.

=head2 Zero-conf? How does this module get/parse/update the CPAN index?

It queries the CPAN Meta DB site at L<http://cpanmetadb.plackperl.org/>.
The site is updated at least every hour to reflect the latest changes
from fast syncing mirrors. The script then also falls back to query the
module at L<http://metacpan.org/> using its wonderful API.

Fetched files are unpacked in C<~/.cpanm> and automatically cleaned up
periodically.  You can configure the location of this with the
C<PERL_CPANM_HOME> environment variable.

=head2 Where does this install modules to? Do I need root access?

It installs to wherever ExtUtils::MakeMaker and Module::Build are
configured to (via C<PERL_MM_OPT> and C<PERL_MB_OPT>). So if you're
using local::lib, then it installs to your local perl5
directory. Otherwise it installs to the site_perl directory that
belongs to your perl.

cpanminus at a boot time checks whether you have configured
local::lib, or have the permission to install modules to the site_perl
directory.  If neither, it automatically sets up local::lib compatible
installation path in a C<perl5> directory under your home
directory. To avoid this, run the script as the root user, with
C<--sudo> option or with C<--local-lib> option.

=head2 cpanminus can't install the module XYZ. Is it a bug?

It is more likely a problem with the distribution itself. cpanminus
doesn't support or is known to have issues with distributions like as
follows:

=over 4

=item *

Tests that require input from STDIN.

=item *

Tests that might fail when C<AUTOMATED_TESTING> is enabled.

=item *

Modules that have invalid numeric values as VERSION (such as C<1.1a>)

=back

These failures can be reported back to the author of the module so
that they can fix it accordingly, rather than me.

=head2 Does cpanm support the feature XYZ of L<CPAN> and L<CPANPLUS>?

Most likely not. Here are the things that cpanm doesn't do by
itself. And it's a feature - you got that from the name I<minus>,
right?

If you need these features, use L<CPAN>, L<CPANPLUS> or the standalone
tools that are mentioned.

=over 4

=item *

Bundle:: module dependencies

=item *

CPAN testers reporting

=item *

Building RPM packages from CPAN modules

=item *

Listing the outdated modules that needs upgrading. See L<App::cpanoutdated>

=item *

Uninstalling modules. See L<pm-uninstall>.

=item *

Showing the changes of the modules you're about to upgrade. See L<cpan-listchanges>

=item *

Patching CPAN modules with distroprefs.

=back

See L<cpanm> or C<cpanm -h> to see what cpanminus I<can> do :)

=head1 COPYRIGHT

Copyright 2010- Tatsuhiko Miyagawa

The standalone executable contains the following modules embedded.

=over 4

=item L<CPAN::DistnameInfo> Copyright 2003 Graham Barr

=item L<Parse::CPAN::Meta> Copyright 2006-2009 Adam Kennedy

=item L<local::lib> Copyright 2007-2009 Matt S Trout

=item L<HTTP::Tiny> Copyright 2011 Christian Hansen

=item L<Module::Metadata> Copyright 2001-2006 Ken Williams. 2010 Matt S Trout

=item L<version> Copyright 2004-2010 John Peacock

=item L<JSON::PP> Copyright 2007−2011 by Makamaka Hannyaharamitu

=item L<CPAN::Meta>, L<CPAN::Meta::Requirements> Copyright (c) 2010 by David Golden and Ricardo Signes

=item L<CPAN::Meta::YAML> Copyright 2010 Adam Kennedy

=item L<File::pushd> Copyright 2012 David Golden

=back

=head1 LICENSE

Same as Perl.

=head1 CREDITS

=head2 CONTRIBUTORS

Patches and code improvements were contributed by:

Goro Fuji, Kazuhiro Osawa, Tokuhiro Matsuno, Kenichi Ishigaki, Ian
Wells, Pedro Melo, Masayoshi Sekimura, Matt S Trout (mst), squeeky,
horus and Ingy dot Net.

=head2 ACKNOWLEDGEMENTS

Bug reports, suggestions and feedbacks were sent by, or general
acknowledgement goes to:

Jesse Vincent, David Golden, Andreas Koenig, Jos Boumans, Chris
Williams, Adam Kennedy, Audrey Tang, J. Shirley, Chris Prather, Jesse
Luehrs, Marcus Ramberg, Shawn M Moore, chocolateboy, Chirs Nehren,
Jonathan Rockway, Leon Brocard, Simon Elliott, Ricardo Signes, AEvar
Arnfjord Bjarmason, Eric Wilhelm, Florian Ragwitz and xaicron.

=head1 COMMUNITY

=over 4

=item L<http://github.com/miyagawa/cpanminus> - source code repository, issue tracker

=item L<irc://irc.perl.org/#toolchain> - discussions about Perl toolchain. I'm there.

=back

=head1 NO WARRANTY

This software is provided "as-is," without any express or implied
warranty. In no event shall the author be held liable for any damages
arising from the use of the software.

=head1 SEE ALSO

L<CPAN> L<CPANPLUS> L<pip>

=cut

1;
