# NAME

App::cpanminus - get, unpack, build and install modules from CPAN

# SYNOPSIS

    cpanm Catalyst
    cpanm MIYAGAWA/Plack-1.0000.tar.gz
    cpanm ~/mydists/MyCompany-Framework-1.0.tar.gz
    cpanm http://example.com/MyModule-0.1.tar.gz
    cpanm http://github.com/miyagawa/Tatsumaki/tarball/master
    cpanm -v Task::Kensho

Run `cpanm -h` for more options.

# DESCRIPTION

cpanminus is a script to get, unpack, build and install modules from CPAN.

Its catch? Deps-free, zero-conf, standalone but maintainable and
extensible with plugins. In the runtime it only requires 8MB of
RAM.

# INSTALLATION

If you have git,

    git clone git://github.com/miyagawa/cpanminus.git
    cd cpanminus
    perl Makefile.PL
    make install

Otherwise,

    cd ~/bin
    wget http://xrl.us/cpanm
    chmod +x cpanm
    # edit shebang if you don't have /usr/bin/env

# DEPENDENCIES

perl 5.8 or later (Actually I believe it works with pre 5.8 too but
haven't tested).

- LWP or 'wget' to get files over HTTP.
- 'tar' executable (if GNU tar, version 1.22 or later) or Archive::Tar to unpack files.
- C compiler, if you want to build XS modules.

And optionally:

- make, if you want to more reliably install MakeMaker based modules
- Module::Build (core in 5.10) if you want to install MakeMaker based modules without 'make'

# QUESTIONS

## Another CPAN installer? What's the point?

OK, the first motivation was this: CPAN shell gets OOM (or swaps
heavily and gets really slow) on Slicehost/linode's most affordable
plan with only 256MB RAM. Should I pay more to install perl modules
from CPAN? I don't think so.

## But why a new client?

I don't have an intention to dis CPAN or CPANPLUS developers. They're
great tools and I've been using it for _literally_ years (Oh, you
know how many modules I have on CPAN, right?) I really respect their
efforts of maintaining the most important tools in the CPAN toolchain
ecosystem.

However, I've learned that for less experienced users (mostly from
outside the Perl community), or even really experienced Perl
developers who knows how to shoot in their feet, setting up the CPAN
toolchain could often feel really yak shaving, especially when all
they want to do is just install some modules and start writing some
perl code.

In particular, here are the few issues I've been observing:

- Too many questions. No sane defaults.
- Bootstrap problems. Nearly impossible to fix when newbies encounter this.
- Noisy output by default.
- Fetches and rebuilds indexes like every day and takes like a minute
- ... and hogs 200MB of memory and thrashes/OOMs on my 256MB VPS

And cpanminus is designed to be very quiet (but logs all output to
`~/.cpanm/build.log`), pick whatever the sanest defaults as possible
without asking any questions to _just work_.

Note that most of these problems with existing tools are rare, or are
just overstated and might be already fixed issues, or can be
configured to work nicer. And I know there's a reason to have many
options and questions, since they're meant to work everywhere for
everybody.

And yes, of course I should have contributed back to CPAN/CPANPLUS
instead of writing a new client, but CPAN.pm is nearly impossible to
maintain (that's why CPANPLUS was born, right?) and CPANPLUS is a huge
beast for me to start working on.

And yes, I think my brain has been damaged since I looked at PyPI,
gemcutter, pip and rip. They're quite nice and I really wanted
something as nice for CPAN which I love.

## How does this thing work?

So, imagine you don't have CPAN or CPANPLUS. What you're going to do
is to search the module on the CPAN search site, download a tarball,
unpack it and then run `perl Makefile.PL` (or `perl Build.PL`). If
the module has dependencies you probably have to recurively resolve
those dependencies by hand before doing so. And then run the unit
tests and `make install` (or `./Build install`).

This script just automates that.

## Zero-conf? How does this module get/parse/update the CPAN index?

It scrapes the site <http://search.cpan.org/>. Yes, it's horrible and
fragile. I hope (and have already talked to) QA/toolchain people for
building a queriable CPAN DB website so I can stop scraping.

Fetched files are unpacked in `~/.cpanm` but you can configure with
`CPANMINUS_HOME` environment variable.

## Where does this install modules to?

It installs to wherever ExtUtils::MakeMaker and Module::Build are
configured to (i.e. via `PERL_MM_OPT` and `MODULEBUILDRC`). So if
you use local::lib then it installs to your local perl5
directory. Otherwise it installs to siteperl directory.

cpanminus at a boot time checks whether you configured local::lib
setup, or have the permission to install modules to the sitelib
directory, and warns you otherwise so that you need to run `cpanm`
command as root, or run with `--sudo` option to auto sudo when
running the install command.

## Does this really work?

I tested installing MojoMojo, Task::Kensho, KiokuDB, Catalyst, Jifty
and Plack using cpanminus and the installations including dependencies
were mostly successful. So multiplies of _half of CPAN_ behave really
nicely and appear to work.

However, there are some distributions that will miserably fail,
because of the nasty edge cases (funky archive formats, naughty
tarball that extracts to the current directory, META.yml that is
outdated and cannot be resurrected, Bundle:: modules, circular
dependencies etc.) while CPAN and CPANPLUS can possibly handle them.

Well in other words, cpanminus is aimed to work against 99% of modules
on CPAN for 99% of people. It may not be perfect, but it should just
work in most cases.

## That sounds fantastic. Should I switch to this from CPAN(PLUS)?

If you've got CPAN or CPANPLUS working then you may keep using CPAN or
CPANPLUS in the longer term, but I just hope this can be a quite handy
alternative to them for people in other situations. And apparently,
many people love (at least the idea of) this software :)

# PLUGINS

cpanminus can be extended by writing plugins. Plugins are flat perl
script that should be placed inside `~/.cpanm/plugins`. See
`plugins/` directory in the distribution for the list of available
and sample plugins.

# COPYRIGHT

Copyright 2010- Tatsuhiko Miyagawa

[Parse::CPAN::Meta](http://search.cpan.org/search?mode=module&query=Parse::CPAN::Meta), included in this script, is Copyright 2006-2009 Adam Kennedy

# LICENSE

Same as Perl.

# CREDITS

Patches contributed by: Goro Fuji, Kazuhiro Osawa, Tokuhiro Matsuno,
Kenichi Ishigaki, Ian Wells, Pedro Melo.

Feedbacks sent by: Jesse Vincent, David Golden, Chris Williams, Matt S
Trout, Adam Kennedy, J. Shirley, Chris Prather, Jesse Luehrs, Marcus
Ramberg, Shawn M Moore, chocolateboy, Ingy dot Net, Chirs Nehren.

# NO WARRANTY

This software is provided "as-is," without any express or implied
warranty. In no event shall the author be held liable for any damages
arising from the use of the software.

# SEE ALSO

[CPAN](http://search.cpan.org/search?mode=module&query=CPAN) [CPANPLUS](http://search.cpan.org/search?mode=module&query=CPANPLUS) [pip](http://search.cpan.org/search?mode=module&query=pip)