# NAME

**App::cpanminus - get, unpack, build and install modules from CPAN**

# SYNOPSIS

    cpanm Module

Run `cpanm -h` or `perldoc cpanm` for more options.

# DESCRIPTION

cpanminus is a script to get, unpack, build and install modules from
CPAN and does nothing else.

It's dependency free (can bootstrap itself), requires zero configuration, 
and stands alone. When running, it requires only 10MB of RAM.

# INSTALLATION

There are several ways to install cpanminus to your system.

## Package management system

There are Debian packages, RPMs, FreeBSD ports, and packages for other
operation systems available. If you want to use the package management system,
search for cpanminus and use the appropriate command to install. This makes it
easy to install `cpanm` to your system without thinking about where to
install, and later upgrade.

## Installing to system perl

You can also use the latest cpanminus to install cpanminus itself:

    curl -L http://cpanmin.us | perl - --sudo App::cpanminus

This will install `cpanm` to your `bin` directory (like `/usr/local/bin`,
unless you configured `INSTALL_BASE` with
[`local::lib`](http://search.cpan.org/perldoc?local::lib)). 

You probably need the `--sudo` option for this installation.

## Installing to local perl (perlbrew)

If you have perl in your home directory (which is the case if you use
tools like [perlbrew](http://search.cpan.org/perldoc?perlbrew)), you don't
need the `--sudo` option, since you're likely to have write permissions 
to perl's library path. Just do this:

    curl -L http://cpanmin.us | perl - App::cpanminus

to install the `cpanm` executable to perl's bin path (like
`~/perl5/perlbrew/bin/cpanm`).

## Downloading the standalone executable

You can also copy the standalone executable to whatever location you'd like.

    cd ~/bin
    curl -LO http://xrl.us/cpanm
    chmod +x cpanm
    # edit shebang if you don't have /usr/bin/env

This just works, but be sure to grab the new version manually when you
upgrade, as `--self-upgrade` might not work for this.

# DEPENDENCIES

perl 5.8 or later.

- `tar` executable
  - Recommended: `bsdtar` or GNU `tar` version 1.22
  - `Archive::Tar` to unpack files
- C compiler, if you want to build XS modules
- `make`
- `Module::Build` (core in `5.10`)

# QUESTIONS

## Another CPAN installer?

Okay, the first motivation was this: the CPAN shell runs out of memory (or swaps
heavily and gets really slow) on Slicehost/linode's most affordable plan with
only 256MB RAM. Should I pay more to install perl modules from CPAN? 

I don't think so.

## But why a new client?

First of all, let me be clear that CPAN and CPANPLUS are great tools
I've used for _literally_ years. (You know how many [modules](http://search.cpan.org/~miyagawa/) 
I have on CPAN, right?) I really respect their efforts of maintaining the most
important tools in the CPAN toolchain ecosystem.

However, for less experienced users (mostly from outside the Perl community)--
or even really experienced Perl developers who know how to shoot themselves in
their feet--setting up the CPAN toolchain often feels like shaving a yak,
especially when all they want to do is just install some modules and start
writing code.

## Zero-conf? How does this module get/parse/update the CPAN index?

It queries the CPAN Meta DB site at [http://cpanmetadb.plackperl.org/](http://cpanmetadb.plackperl.org/).
The site is updated at least every hour to reflect the latest changes
from fast syncing mirrors. The script then also falls back to query the
module at [http://metacpan.org/](http://metacpan.org/) using its wonderful API.

Upon calling these API hosts, `cpanm` (since version 1.6004) will send the
local `perl` versions to the server in the `User-Agent` string by default. 
You can turn it off with `--no-report-perl-version` option. 

Read more about the option with [cpanm](http://search.cpan.org/perldoc?cpanm), 
and read more about the privacy policy about this data collection at 
[http://cpanmetadb.plackperl.org/\#privacy](http://cpanmetadb.plackperl.org/\#privacy)

Fetched files are unpacked in `~/.cpanm`, and are periodically cleaned up
automatically. You can configure the location of this with the 
`PERL_CPANM_HOME` environment variable.

## Where does this install modules to? Do I need root access?

It installs to wherever `ExtUtils::MakeMaker` and `Module::Build` are
configured to (via `PERL_MM_OPT` and `PERL_MB_OPT`). So, if you're
using `local::lib`, then it installs to your local perl5
directory. Otherwise, it installs to the site\_perl directory that
belongs to your perl.

At boot time, cpanminus checks whether you have configured
`local::lib`, or have the permission to install modules to the site\_perl
directory.  If neither are true, it automatically sets up `local::lib` 
compatible installation path in a `perl5` directory under your home
directory. To avoid this, run the script as the `root` user (with either 
the `--sudo` or `--local-lib` option).

## cpanminus can't install the module XYZ. Is it a bug?

It is more likely a problem with the distribution itself. cpanminus
doesn't support, or is known to have issues with distributions, as
follows:

- Tests that require input from `STDIN`
- Tests that might fail when `AUTOMATED_TESTING` is enabled
- Modules that have invalid numeric values as VERSION (such as `1.1a`)

These failures can be reported back to the author of the module, so they can fix it, 
rather than me.

## Does cpanm support the feature XYZ of [CPAN](http://search.cpan.org/perldoc?CPAN) and [CPANPLUS](http://search.cpan.org/perldoc?CPANPLUS)?

Most likely not. Here are the things that cpanm doesn't do by
itself. (And it's a feature--you got that from the name _minus_,
right?)

- CPAN testers reporting
- Building RPM packages from CPAN modules
- Listing the outdated modules that needs upgrading. See [App::cpanoutdated](http://search.cpan.org/perldoc?App::cpanoutdated)
- Showing the changes of the modules you're about to upgrade. See [cpan-listchanges](http://search.cpan.org/perldoc?cpan-listchanges)
- Patching CPAN modules with distroprefs.

If you need these features, use [CPAN](http://search.cpan.org/perldoc?CPAN), [CPANPLUS](http://search.cpan.org/perldoc?CPANPLUS), or the standalone
tools that are mentioned.

See [cpanm](http://search.cpan.org/perldoc?cpanm) or `cpanm -h` to see what cpanminus _can_ do. :)

# COPYRIGHT

Copyright 2010, Tatsuhiko Miyagawa

The standalone executable contains the following embedded modules:

- [CPAN::DistnameInfo](http://search.cpan.org/perldoc?CPAN::DistnameInfo) Copyright 2003 Graham Barr
- [Parse::CPAN::Meta](http://search.cpan.org/perldoc?Parse::CPAN::Meta) Copyright 2006-2009 Adam Kennedy
- [local::lib](http://search.cpan.org/perldoc?local::lib) Copyright 2007-2009 Matt S Trout
- [HTTP::Tiny](http://search.cpan.org/perldoc?HTTP::Tiny) Copyright 2011 Christian Hansen
- [Module::Metadata](http://search.cpan.org/perldoc?Module::Metadata) Copyright 2001-2006 Ken Williams. 2010 Matt S Trout
- [version](http://search.cpan.org/perldoc?version) Copyright 2004-2010 John Peacock
- [JSON::PP](http://search.cpan.org/perldoc?JSON::PP) Copyright 2007-2011 by Makamaka Hannyaharamitu
- [CPAN::Meta](http://search.cpan.org/perldoc?CPAN::Meta), [CPAN::Meta::Requirements](http://search.cpan.org/perldoc?CPAN::Meta::Requirements) Copyright (c) 2010 by David Golden and Ricardo Signes
- [CPAN::Meta::YAML](http://search.cpan.org/perldoc?CPAN::Meta::YAML) Copyright 2010 Adam Kennedy
- [File::pushd](http://search.cpan.org/perldoc?File::pushd) Copyright 2012 David Golden

# LICENSE

This software is licensed under the same terms as Perl.

# CREDITS

## CONTRIBUTORS

Patches and code improvements were contributed by:

Goro Fuji, Kazuhiro Osawa, Tokuhiro Matsuno, Kenichi Ishigaki, Ian
Wells, Pedro Melo, Masayoshi Sekimura, Matt S Trout (mst), squeeky,
horus and Ingy dot Net.

## ACKNOWLEDGEMENTS

Bug reports, suggestions and feedbacks were sent by, or general
acknowledgement goes to:

Jesse Vincent, David Golden, Andreas Koenig, Jos Boumans, Chris
Williams, Adam Kennedy, Audrey Tang, J. Shirley, Chris Prather, Jesse
Luehrs, Marcus Ramberg, Shawn M Moore, chocolateboy, Chirs Nehren,
Jonathan Rockway, Leon Brocard, Simon Elliott, Ricardo Signes, AEvar
Arnfjord Bjarmason, Eric Wilhelm, Florian Ragwitz and xaicron.

# COMMUNITY

- [http://github.com/miyagawa/cpanminus](http://github.com/miyagawa/cpanminus) - source code repository, issue tracker
- [irc://irc.perl.org/\#toolchain](irc://irc.perl.org/\#toolchain) - discussions about Perl toolchain. I'm there.

# NO WARRANTY

This software is provided "as-is," without any express or implied
warranty. In no event shall the author be held liable for any damages
arising from the use of the software.

# SEE ALSO

- [CPAN](http://search.cpan.org/perldoc?CPAN) 
- [CPANPLUS](http://search.cpan.org/perldoc?CPANPLUS) 
- [pip](http://search.cpan.org/perldoc?pip)
