package App::cpanminus;
our $VERSION = "1.0011";

=head1 NAME

App::cpanminus - get, unpack, build and install modules from CPAN

=head1 SYNOPSIS

    cpanm Module

Run C<cpanm -h> for more options.

=head1 DESCRIPTION

cpanminus is a script to get, unpack, build and install modules from CPAN.

Why? It's dependency free, requires zero configuration, and stands
alone. When running, it requires only 10MB of RAM.

=head1 INSTALLATION

There are Debian packages, RPMs, FreeBSD ports, and packages for other
operation systems available. If you want to use the package management system,
search for cpanminus and use the appropriate command to install. This makes it
easy to install C<cpanm> to your system without thinking about where to
install, and later upgrade.

You can also use the latest cpanminus to install cpanminus itself (aka bootstrap):

    curl -L http://cpanmin.us | perl - --sudo App::cpanminus

This will install C<cpanm> to your bin directory like
C</usr/local/bin> (unless you configured C<INSTALL_BASE> with
L<local::lib>), so you might need the C<--sudo> option.

Later you can say C<cpanm --self-upgrade --sudo> to upgrade to the
latest version.

Otherwise,

    cd ~/bin
    wget http://xrl.us/cpanm
    chmod +x cpanm
    # edit shebang if you don't have /usr/bin/env

just works, but be sure to grab the new version manually when you
upgrade (C<--self-upgrade> might not work).

=head1 DEPENDENCIES

perl 5.8 or later.

=over 4

=item *

'tar' executable (bsdtar or GNU tar version 1.22 are rcommended) or Archive::Tar to unpack files.

=item *

C compiler, if you want to build XS modules.

=back

And optionally:

=over 4

=item *

make, if you want to reliably install MakeMaker based modules

=item *

Module::Build (core in 5.10) to install Build.PL based modules

=back

=head1 QUESTIONS

=head2 Another CPAN installer?

OK, the first motivation was this: the CPAN shell runs out of memory (or swaps
heavily and gets really slow) on Slicehost/linode's most affordable plan with
only 256MB RAM. Should I pay more to install perl modules from CPAN? I don't
think so.

=head2 But why a new client?

First of all, I have no intention to dis CPAN or CPANPLUS
developers. Don't get me wrong. They're great tools I've 
used for I<literally> years (you know how many modules I have
on CPAN, right?). I really respect their efforts of maintaining the
most important tools in the CPAN toolchain ecosystem.

However, for less experienced users (mostly from outside the Perl community),
or even really experienced Perl developers who know how to shoot themselves in
their feet, setting up the CPAN toolchain often feels like yak shaving,
especially when all they want to do is just install some modules and start
writing code.

In particular, here are the few issues I've observed:

=over

=item *

They ask too many questions and do not provide enough sane defaults. A normal
user doesn't (and shouldn't have to) know what's the right answer for the
question C<Parameters for the 'perl Build.PL' command? []>

=item *

They provide very noisy output by default.

=item *

They fetch and rebuild their indexes almost every day, and this takes time.

=item *

... and they hog 200MB of memory and thrashes/OOMs on my 256MB VPS

=back

cpanminus is designed to be very quiet (but logs all output to
C<~/.cpanm/build.log>) and to pick the sanest possible defaults without asking
any questions -- to I<just work>.

Note that most of these problems with existing tools are rare, or are just
overstated.  They might already be fixed, or can be configured to work nicer.
For instance, the latest CPAN.pm dev release has a much better first time
configuration experience than ever before.

I know there's a reason for them to have many options and questions, because
they're meant to work everywhere for everybody.

Of course I should have contributed back to CPAN/CPANPLUS
instead of writing a new client, but CPAN.pm is nearly impossible
(for anyone other than andk or xdg) to maintain (that's why CPANPLUS
was born, right?) and CPANPLUS is a huge beast for me to start working
on.

=head2 Are you on drugs?

Yeah, I think my brain has been damaged since I looked at PyPI,
gemcutter, pip and rip. They're quite nice and I really wanted
something as nice for CPAN which I love.

=head2 How does this thing work?

Imagine you don't have CPAN or CPANPLUS. You search for a module on the CPAN
search site, download a tarball, unpack it and then run C<perl Makefile.PL> (or
C<perl Build.PL>). If the module has dependencies you probably have to resolve
those dependencies by hand before doing so. Then you run the unit tests and
C<make install> (or C<./Build install>).

cpanminus automates that.

=head2 Zero-conf? How does this module get/parse/update the CPAN index?

It queries the CPAN Meta DB site running on Google AppEngine at
L<http://cpanmetadb.appspot.com/>. The site is updated every hour to reflect
the latest changes from fast syncing mirrors. The script then also falls back
to the site L<http://search.cpan.org/>. I've been talking to and working with
with the QA/toolchain people for building a more reliable CPAN DB website.

Fetched files are unpacked in C<~/.cpanm>.  You can configure this with
the C<PERL_CPANM_HOME> environment variable.

=head2 Where does this install modules to? Do I need root access?

It installs to wherever ExtUtils::MakeMaker and Module::Build are
configured to (via C<PERL_MM_OPT> and C<MODULEBUILDRC>). So if
you're using local::lib, then it installs to your local perl5
directory. Otherwise it installs to the siteperl directory.

cpanminus at a boot time checks whether you have configured local::lib, or have
the permission to install modules to the sitelib directory.  If neither, it
automatically sets up local::lib compatible installation path in a C<perl5>
directory under your home directory. To avoid this, run the script as the root
user, with C<--sudo> option or with C<--local-lib> option.

This L<local::lib> automatic integration is still considered alpha and
in the work -- more bootstrapping is under development. Stay tuned.

=head2 Does this really work?

I tested installing MojoMojo, Task::Kensho, KiokuDB, Catalyst, Jifty and Plack
using cpanminus and the installations including dependencies were mostly
successful. More than I<half of CPAN> behaves really nicely and appears to
work.

However, there might be some distributions that will miserably fail, because of
nasty edge cases. Here are some examples:

=over 4

=item *

Packages uploaded to PAUSE in 90s which don't live under the standard
C<authors/id/A/AA> directory hierarchy.

=item *

Distributions with a C<Makefile.PL> or C<Build.PL> that asks you questions
without using C<prompt> function. However cpanminus has a mechanism to kill
those questions with a timeout, and you can always say C<--interactive> to make
the configuration interactive.

=item *

Distributions that do not shipped with C<META.yml> file but do require
some specific version of toolchain for configuration.

=item *

Distributions that have a C<META.yml> file that is encoded in YAML 1.1 format
using L<YAML::XS>. This will be eventually solved once we move to C<META.json>.

=back

cpanminus intends to work for 99.9% of modules on CPAN for 99.9% of people. It
may not be perfect, but it should just work in most cases.

If this tool doesn't work for your very rare environment, then I'm sorry, but
you should use CPAN or CPANPLUS, or build and install modules manually.

=head2 That sounds fantastic. Should I switch to this from CPAN(PLUS)?

If you have CPAN or CPANPLUS working then you may want to keep using
CPAN or CPANPLUS in the longer term, but I hope this can be a
quite handy alternative to them for people in other situations. And
apparently, many people love (at least the idea of) this software :)

=head1 COPYRIGHT

Copyright 2010- Tatsuhiko Miyagawa

The standalone executable contains the following modules embedded.

=over 4

=item L<Parse::CPAN::Meta> Copyright 2006-2009 Adam Kennedy

=item L<local::lib> Copyright 2007-2009 Matt S Trout

=item L<HTTP::Lite> Copyright 2000-2002 Roy Hopper, 2009 Adam Kennedy

=item L<Module::Metadata> Copyright 2001-2006 Ken Williams. 2010 Matt S Trout

=back

=head1 LICENSE

Same as Perl.

=head1 CREDITS

=head2 CONTRIBUTORS

Patches and code improvements were contributed by:

Goro Fuji, Kazuhiro Osawa, Tokuhiro Matsuno, Kenichi Ishigaki, Ian
Wells, Pedro Melo, Masayoshi Sekimura, Matt S Trout, squeeky, horus
and Ingy dot Net.

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
