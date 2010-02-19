cpanminus - get, unpack, build and install modules from CPAN

## What is this? 

cpanminus is a script to unpack, build and install modules from CPAN.

Its catch? Deps-free, zero-conf, standalone ~200 LOC script
(i.e. hackable) and requires only 10MB RAM. See below for its cons.

## Installation

Grab the file, chmod +x, put it into your PATH. (Adjust shebang if needed)

## Should I really use this?

No. Use CPAN or CPANPLUS.

## WTF? Why did you make this?

CPAN shell gets OOM (or swaps heavily and gets really slow) on
Slicehost/linode's most affordable plan with only 256MB RAM.

Yes, I know CPAN::SQLite can fix it but installing it and its 14
non-core dependencies without CPAN shell (because CPAN shell doesn't
work) feels like yak shaving.

So, imagine you don't have CPAN or CPANPLUS. What you're going to do
is to search the module on the CPAN search site, download a tarball,
unpack it and then run `perl Makefile.PL` (or `perl Build.PL`) and
then `make install`. If the module has dependencies you probably have
to recurively resolve those dependencies by hand before doing so.

This script just automates that.

## Zero-conf? How does this module get/parse/update the CPAN index?

It scrapes the site http://search.cpan.org/. Yes, it's horrible and
fragile.

## Configuration

Fetched files are unpacked in `~/.cpanm` but you can configure with
`CPANMINUS_HOME` environment variable.

## What do you need to run this?

perl 5.8 or later (Actually I believe it works with pre 5.8 too but
haven't tested).

* LWP or 'wget' to get files over HTTP.
* 'tar' executable or Archive::Tar to unpack files.
* make (Ugh!)
* C compiler, if you want to build XS modules.

## Does this work with local::lib?

Yes.

## Does this really work?

I tested installing Moose, Catalyst, Jifty and Plack using cpanminus
and the installation including dependencies was all successful.

There are some distributions that will miserably fail, because of the
nasty edge cases (funky archive formats, naughty tarball that extracts
to the current directory, META.yml that is actually JSON, circular
dependencies etc.) while CPAN and CPANPLUS can handle them.

## Quick Install?

Oh, you mean `env PERL_MM_USE_DEFAULT=1 cpanm --notest Module`

Don't do that. It's too useful.

## So you're ignoring the CPAN toolchain ecosystem with this?

No, that's not my intention. As a developer with 190 modules on CPAN,
I appreciate and respect the CPAN toolchain developers for their great
effort.

However I've learned that in some rare cases, especially for less
experienced users (or really experienced users who knows how to shoot
their feet), setting up a CPAN toolchain "in the right way" feels like
just another yak to shave, and this tool is a super tiny shaver to
eliminate the big yak really quickly and does nothing else.

## Should I really use this?

No. Use CPAN or CPANPLUS.

## COPYRIGHT

Copyright 2010- Tatsuhiko Miyagawa

## AUTHORS

Tatsuhiko Miyagawa, Goro Fuji, Kazuhiro Osawa, Tokuhiro Matsuno

