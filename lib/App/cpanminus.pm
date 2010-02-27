package App::cpanminus;
our $VERSION = "0.99_06";

=head1 NAME

App::cpanminus - get, unpack, build and install modules from CPAN

=head1 SYNOPSIS

    cpanm Module
    cpanm MIYAGAWA/Plack-1.0000.tar.gz
    cpanm ~/mydists/MyCompany-Framework-1.0.tar.gz
    cpanm http://example.com/MyModule-0.1.tar.gz
    cpanm http://github.com/miyagawa/Tatsumaki/tarball/master
    cpanm --interactive Task::Kensho

Run C<cpanm -h> for more options.

=head1 DESCRIPTION

cpanminus is a script to get, unpack, build and install modules from CPAN.

Its catch? Deps-free, zero-conf, standalone but maintainable and
extensible with plugins and shell scripting friendly. In the runtime
it only requires 10MB of RAM.

=head1 INSTALLATION

There are Debian package, RPM, FreeBSD ports and packages for other
operation systems available. If you want to use the package maangement
system, search for cpanminus and use the appropriate command to
install. This makes it easy to install C<cpanm> to your system and
later upgrade.

If you want to build the latest from source,

    git clone git://github.com/miyagawa/cpanminus.git
    cd cpanminus
    perl Makefile.PL
    make install # or sudo make install if you're non root

This will install C<cpanm> to your bin directory like
C</usr/local/bin> (unless you configured C<INSTALL_BASE> with
L<local::lib>), so you might need to sudo. Later you can say C<cpanm
--self-upgrade --sudo> to upgrade to the latest version.

Otherwise,

    cd ~/bin
    wget http://xrl.us/cpanm
    chmod +x cpanm
    # edit shebang if you don't have /usr/bin/env

just works, but be sure to grab the new version manually when you
upgrade (C<--self-upgrade> might not work).

=head1 DEPENDENCIES

perl 5.8 or later (Actually I believe it works with pre 5.8 too but
haven't tested).

=over 4

=item *

'tar' executable (if GNU tar, version 1.22 or later) or Archive::Tar to unpack files.

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

=head1 PLUGINS

B<WARNING: plugin API is not stable so this feature is turned off by
default for now. To enable plugins you have to be savvy enough to look
at the build.log or read the source code to see how :)>

cpanminus core is a compact and simple 1000 lines of code (with some
embedded utilities and documents) but can be extended by writing
plugins. Plugins are flat perl scripts that should be placed inside
C<~/.cpanm/plugins>. You can copy (or symlink, if you're a developer)
a plugin file to the directory to enable plugins, and delete the
file to disable.

See C<plugins/> directory in the git repository
L<http://github.com/miyagawa/cpanminus> for the list of available and
sample plugins.

=head1 QUESTIONS

=head2 Another CPAN installer?

OK, the first motivation was this: CPAN shell gets OOM (or swaps
heavily and gets really slow) on Slicehost/linode's most affordable
plan with only 256MB RAM. Should I pay more to install perl modules
from CPAN? I don't think so.

=head2 But why a new client?

First of all, I don't have an intention to dis CPAN or CPANPLUS
developers. Don't get me wrong. They're great tools and I've been
using it for I<literally> years (Oh, you know how many modules I have
on CPAN, right?) I really respect their efforts of maintaining the
most important tools in the CPAN toolchain ecosystem.

However, I've learned that for less experienced users (mostly from
outside the Perl community), or even really experienced Perl
developers who knows how to shoot in their feet, setting up the CPAN
toolchain could often feel really yak shaving, especially when all
they want to do is just install some modules and start writing some
perl code.

In particular, here are the few issues I've been observing:

=over

=item *

Too many questions. No sane defaults. Normal user doesn't (and
shouldn't have to) know what's the right answer for the question
C<Parameters for the 'perl Build.PL' command? []>

=item *

Very noisy output by default.

=item *

Fetches and rebuilds indexes like every day and takes like a minute

=item *

... and hogs 200MB of memory and thrashes/OOMs on my 256MB VPS

=back

And cpanminus is designed to be very quiet (but logs all output to
C<~/.cpanm/build.log>), pick whatever the sanest defaults as possible
without asking any questions to I<just work>.

Note that most of these problems with existing tools are rare, or are
just overstated and might be already fixed issues, or can be
configured to work nicer. For instance the latest CPAN.pm dev release
has a much better FirstTime experience than previously.

And I know there's a reason for them to have many options and
questions, since they're meant to work everywhere for everybody.

And yes, of course I should have contributed back to CPAN/CPANPLUS
instead of writing a new client, but CPAN.pm is nearly impossibler
(for anyone other than andk or xdg) to maintain (that's why CPANPLUS
was born, right?) and CPANPLUS is a huge beast for me to start working
on.

=head2 Are you on drugs?

Yeah, I think my brain has been damaged since I looked at PyPI,
gemcutter, pip and rip. They're quite nice and I really wanted
something as nice for CPAN which I love.

=head2 How does this thing work?

So, imagine you don't have CPAN or CPANPLUS. What you're going to do
is to search the module on the CPAN search site, download a tarball,
unpack it and then run C<perl Makefile.PL> (or C<perl Build.PL>). If
the module has dependencies you probably have to recursively resolve
those dependencies by hand before doing so. And then run the unit
tests and C<make install> (or C<./Build install>).

This script just automates that.

=head2 Zero-conf? How does this module get/parse/update the CPAN index?

It scrapes the site L<http://search.cpan.org/>. Yes, it's horrible and
fragile. I hope (and have already talked to) QA/toolchain people for
building a queriable CPAN DB website so I can stop scraping.

Fetched files are unpacked in C<~/.cpanm> but you can configure with
C<PERL_CPANM_HOME> environment variable.

=head2 Where does this install modules to? Do I need a root access?

It installs to wherever ExtUtils::MakeMaker and Module::Build are
configured to (i.e. via C<PERL_MM_OPT> and C<MODULEBUILDRC>). So if
you use local::lib then it installs to your local perl5
directory. Otherwise it installs to siteperl directory.

cpanminus at a boot time checks whether you configured local::lib
setup, or have the permission to install modules to the sitelib
directory, and warns you otherwise so that you need to run C<cpanm>
command as root, or run with C<--sudo> option to auto sudo when
running the install command. Yes, it's already in the plan to
automatically bootstraps L<local::lib> at the initial launch if you're
non-root. I'm working on it with local::lib developers -- Stay tuned.

=head2 Does this really work?

I tested installing MojoMojo, Task::Kensho, KiokuDB, Catalyst, Jifty
and Plack using cpanminus and the installations including dependencies
were mostly successful. So multiplies of I<half of CPAN> behave really
nicely and appear to work.

However, there might be some distributions that will miserably fail,
because of the nasty edge case, a.k.a. bad distros. Here are some
examples:

=over 4

=item *

Packages uploaded to PAUSE in 90's and doesn't live under the standard
C<authors/id/A/AA> directory hierarchy.

=item *

C<Makefile.PL> or C<Build.PL> that asks you questions without using
C<prompt> function. However cpanminus has a mechanism to kill those
questions with a timeout, and you can always say C<--interactive> to
make the configuration interactive.

=item *

Distributions that are not shipped with C<META.yml> file but requires
some specific version of toolchain in the configuration time.

=item *

Distributions that tests SIGNATURE in the C<*.t> unit tests and has
C<MANIFEST.SKIP> file in the distribution at the same time. Signature
testing is for the security and running it in unit tests is too late
since we run C<Makefile.PL> in the configuration time. cpanminus has
C<verity_signature> plugin to verify the dist before configurations.

=item *

Distributions that has a C<META.yml> file that is encoded in YAML 1.1
format using L<YAML::XS>. This will be eventually solved once we move
to C<META.json>.

=back

Well in other words, cpanminus is aimed to work against 99.9% of
modules on CPAN for 99.9% of people. It may not be perfect, but it
should just work in most cases.

If this tool doesn't work for your very rare environment, then I'm
sorry, but you should use CPAN or CPANPLUS, or build and install
modules manually.

=head2 That sounds fantastic. Should I switch to this from CPAN(PLUS)?

If you've got CPAN or CPANPLUS working then you may want to keep using
CPAN or CPANPLUS in the longer term, but I just hope this can be a
quite handy alternative to them for people in other situations. And
apparently, many people love (at least the idea of) this software :)

=head1 COPYRIGHT

Copyright 2010- Tatsuhiko Miyagawa

The standalone executable contains the following modules embedded.

=over 4

=item L<Parse::CPAN::Meta> Copyright 2006-2009 Adam Kennedy

=item L<local::lib> Copyright 2007-2009 Matt S Trout

=item L<HTTP::Lite> Copyright 2000-2002 Roy Hopper, 2009 Adam Kennedy

=back

=head1 LICENSE

Same as Perl.

=head1 CREDITS

Patches contributed by: Goro Fuji, Kazuhiro Osawa, Tokuhiro Matsuno,
Kenichi Ishigaki, Ian Wells, Pedro Melo, Masayoshi Sekimura and Matt S
Trout.

Feedbacks sent by: Jesse Vincent, David Golden, Chris Williams, Adam
Kennedy, J. Shirley, Chris Prather, Jesse Luehrs, Marcus Ramberg,
Shawn M Moore, chocolateboy, Ingy dot Net, Chirs Nehren, Jonathan
Rockway and Leon Brocard.

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
