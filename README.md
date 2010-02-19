cpanminus - get, unpack, build and install modules from CPAN

## What is this? 

cpanminus is a tiny script to get, unpack, build and install modules
from CPAN.  It's a single perl script with no dependencies.

## Should I use this?

No. Use CPAN or CPANPLUS.

## WTF? Why did you make this?

CPAN shell sometimes takes ~150MB of memory and it's a pain to run
on a VPS with smaller RAM. This script only requires 10MB or so. (Yes,
I know CPAN::SQLite can fix this)

Often you just want to download the tarball and run perl Makefile.PL
and make install. This script just automates that, but also does
some recursive dependency check as well, which works for 90% of the
use cases if you want to install modules from CPAN.

## How does this module get the CPAN index?

It scrapes http://search.cpan.org/. Yes, it's horrible. Fetched files
are unpacked files in ~/.cpanm

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
successfully.

## So you're damaging the CPAN toolchain ecosystem with this?

No, that's not my intention. As a developer with 190 modules on CPAN,
I appreciate and respect the CPAN toolchain developers for their great
effort. And believe me, I've been contributing a lot to improve the
ecosystem as well with patches for Module::Install and local::lib etc.

However I've learned that in some rare cases (for poor users), setting
up a CPAN toolchain feels like just another yak to shave. This tool is
a super tiny shaver to eliminate the yak in that particular case.

## Should I use this?

No. Use CPAN or CPANPLUS.

## COPYRIGHT

Copyright 2010- Tatsuhiko Miyagawa

## AUTHORS

Tatsuhiko Miyagawa, Goro Fuji, Kazuhiro Osawa, Tokuhiro Matsuno

