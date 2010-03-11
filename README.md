# NAME

App::cpanminus - get, unpack, build and install modules from CPAN

# SYNOPSIS

    cpanm Module
    cpanm MIYAGAWA/Plack-1.0000.tar.gz
    cpanm ~/mydists/MyCompany-Framework-1.0.tar.gz
    cpanm http://example.com/MyModule-0.1.tar.gz
    cpanm http://github.com/miyagawa/Tatsumaki/tarball/master
    cpanm --interactive Task::Kensho

Run `cpanm -h` for more options.

# DESCRIPTION

cpanminus is a script to get, unpack, build and install modules from CPAN.

Why? It's dependency free, requires zero configuration, and stands alone -- but
it's maintainable and extensible with plugins and friendly to shell scripting.
When running, it requires only 10MB of RAM.

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
I haven't tested test.)

- *

LWP or 'wget' to get files over HTTP.

- *

'tar' executable (if GNU tar, version 1.22 or later) or Archive::Tar to unpack files.

- *

C compiler, if you want to build XS modules.

And optionally:

- *

make, if you want to install MakeMaker based modules reliably

- *

Module::Build (core in 5.10) if you want to install MakeMaker based modules without 'make'

# PLUGINS

__WARNING: plugin API is not stable so this feature is turned off by
default for now. To enable plugins you have to be savvy enough to look
at the build.log or read the source code to see how :)__

cpanminus core is tiny at 600 lines of code (with some embedded
utilities and documents) but can be extended by writing
plugins. Plugins are perl scripts placed inside
`~/.cpanm/plugins`. See the `plugins/` directory in the git repository
<http://github.com/miyagawa/cpanminus> for the list of available and
sample plugins.

# QUESTIONS

## Another CPAN installer?

OK, the first motivation was this: the CPAN shell runs out of memory (or swaps
heavily and gets really slow) on Slicehost/linode's most affordable
plan with only 256MB RAM. Should I pay more to install perl modules
from CPAN? I don't think so.

## But why a new client?

First of all, I have no intention to dis CPAN or CPANPLUS
developers. Don't get me wrong. They're great tools and I've 
used for _literally_ years (you know how many modules I have
on CPAN, right?) I really respect their efforts of maintaining the
most important tools in the CPAN toolchain ecosystem.

However, I've learned that for less experienced users (mostly from outside the
Perl community), or even really experienced Perl developers who know how to
shoot themselves in their feet, feel like setting up the CPAN toolchain is yak
shaving, especially when all they want to do is just install some modules and
start writing some perl code.

In particular, here are the few issues I've been observing:

- *

Too many questions. No sane defaults. Normal user doesn't (and
shouldn't have to) know what's the right answer for the question
`Parameters for the 'perl Build.PL' command? []`

- *

Very noisy output by default.

- *

Fetches and rebuilds indexes almost every day, which takes too much time.

- *

... and hogs 200MB of memory and thrashes/OOMs on my 256MB VPS

Cpanminus is designed to be very quiet (but logs all output to
`~/.cpanm/build.log`) and chooses the sanest defaults as possible without
asking any questions to _just work_.

Note that most of these problems with existing tools are rare, or are
overstated, might be already fixed, or can be configured to work nicer. For
instance the latest CPAN.pm dev release has a much better first time user
experience than before.

I also know there's a reason for every option and questions, since those tools
are meant to work everywhere for everybody.

Of course I should have contributed back to CPAN/CPANPLUS instead of writing a
new client, but CPAN.pm is nearly impossible to maintain (that's why CPANPLUS
was born, right?) and CPANPLUS is a huge beast for me to start working on.

## Are you on drugs?

Yeah, I think my brain has been damaged since I looked at PyPI,
gemcutter, pip and rip. They're quite nice and I really wanted
something as nice for CPAN which I love.

## How does this thing work?

Imagine you don't have CPAN or CPANPLUS. What you're going to do is to search
the module on the CPAN search site, download a tarball, unpack it and then run
`perl Makefile.PL` (or `perl Build.PL`). If the module has dependencies you
probably have to recurively resolve those dependencies by hand, then run the
unit tests and `make install` (or `./Build install`).

This script automates that.

## Zero-conf? How does this module get/parse/update the CPAN index?

It scrapes the site <http://search.cpan.org/>. Yes, it's horrible and
fragile. I hope (and have already talked to) QA/toolchain people for
building a queriable CPAN DB website so I can stop scraping.

Fetched files are unpacked in `~/.cpanm`, but you can configure this location
with the `PERL_CPANM_HOME` environment variable.

## Where does this install modules to?

It installs to wherever ExtUtils::MakeMaker and Module::Build are configured to
(i.e. via `PERL_MM_OPT` and `MODULEBUILDRC`). If you use local::lib then it
installs to your local perl5 directory. Otherwise it installs to your siteperl
directory.

cpanminus at boot time checks whether you have configured local::lib or have
the permission to install modules to the sitelib directory.  If not, it warns
you otherwise to run `cpanm` command as root, or run with `--sudo` option to
auto sudo when running the install command.

## Does this really work?

I tested installing MojoMojo, Task::Kensho, KiokuDB, Catalyst, Jifty and Plack
using cpanminus and the installations including dependencies were mostly
successful.  That means at least _half of CPAN_ behaves really nicely and
appears to work.

However, some distributions fail miserably because of nasty edge cases (funky
archive formats, naughty tarball that extracts to the current directory,
META.yml that is outdated and cannot be resurrected, Bundle:: modules, circular
dependencies etc.).  CPAN and CPANPLUS can handle them.

cpanminus is aimed to work against 99% of modules on CPAN for 99% of people. It
may not be perfect, but it should just work in most cases.

## That sounds fantastic. Should I switch to this from CPAN(PLUS)?

If you've got CPAN or CPANPLUS working then you may keep using CPAN or CPANPLUS
in the longer term, but I hope this can be a quite handy alternative to them
for people in other situations. Apparently, many people love (at least the idea
of) this software :)

# COPYRIGHT

Copyright 2010- Tatsuhiko Miyagawa

[Parse::CPAN::Meta](http://search.cpan.org/search?mode=module&query=Parse::CPAN::Meta), included in this script, is Copyright 2006-2009 Adam Kennedy

# LICENSE

Same as Perl.

# CREDITS

Patches contributed by: Goro Fuji, Kazuhiro Osawa, Tokuhiro Matsuno,
Kenichi Ishigaki, Ian Wells, Pedro Melo, Masayoshi Sekimura and Matt S
Trout.

Feedbacks sent by: Jesse Vincent, David Golden, Chris Williams, Adam
Kennedy, J. Shirley, Chris Prather, Jesse Luehrs, Marcus Ramberg,
Shawn M Moore, chocolateboy, Ingy dot Net, Chirs Nehren, Jonathan
Rockway and Leon Brocard.

# COMMUNITY

- <http://github.com/miyagawa/cpanminus> - source code repository, issue tracker

- L<irc://irc.perl.org/#toolchain> - discussions about Perl toolchain. I'm there.

# NO WARRANTY

This software is provided "as-is," without any express or implied
warranty. In no event shall the author be held liable for any damages
arising from the use of the software.

# SEE ALSO

[CPAN](http://search.cpan.org/search?mode=module&query=CPAN) [CPANPLUS](http://search.cpan.org/search?mode=module&query=CPANPLUS) [pip](http://search.cpan.org/search?mode=module&query=pip)
