# NAME

App::cpanminus - get, unpack, build and install modules from CPAN

# SYNOPSIS

    cpanm Module

Run `cpanm -h` or `perldoc cpanm` for more options.

# DESCRIPTION

cpanminus is a script to get, unpack, build and install modules from
CPAN and does nothing else.

It's dependency free (can bootstrap itself), requires zero
configuration, and stands alone. When running, it requires only 10MB
of RAM.

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

    curl -L https://cpanmin.us | perl - --sudo App::cpanminus

This will install `cpanm` to your bin directory like
`/usr/local/bin` and you'll need the `--sudo` option to write to
the directory, unless you configured `INSTALL_BASE` with [local::lib](https://metacpan.org/pod/local%3A%3Alib).

## Installing to local perl (perlbrew, plenv etc.)

If you have perl in your home directory, which is the case if you use
tools like [perlbrew](https://metacpan.org/pod/perlbrew) or plenv, you don't need the `--sudo` option, since
you're most likely to have a write permission to the perl's library
path. You can just do:

    curl -L https://cpanmin.us | perl - App::cpanminus

to install the `cpanm` executable to the perl's bin path, like
`~/perl5/perlbrew/bin/cpanm`.

## Downloading the standalone executable

You can also copy the standalone executable to whatever location you'd like.

    cd ~/bin
    curl -L https://cpanmin.us/ -o cpanm
    chmod +x cpanm

This just works, but be sure to grab the new version manually when you
upgrade because `--self-upgrade` might not work with this installation setup.

## Troubleshoot: HTTPS warnings

When you run `curl` commands above, you may encounter SSL handshake
errors or certification warnings. This is due to your HTTP client
(curl) being old, or SSL certificates installed on your system needs
to be updated.

You're recommended to update the software or system if you can. If
that is impossible or difficult, use the `-k` option with curl.

# DEPENDENCIES

perl 5.8.1 or later.

- 'tar' executable (bsdtar or GNU tar version 1.22 are recommended) or Archive::Tar to unpack files.
- C compiler, if you want to build XS modules.
- make
- Module::Build (core in 5.10)

# QUESTIONS

## How does cpanm get/parse/update the CPAN index?

It queries the CPAN Meta DB site at [http://cpanmetadb.plackperl.org/](http://cpanmetadb.plackperl.org/).
The site is updated at least every hour to reflect the latest changes
from fast syncing mirrors. The script then also falls back to query the
module at [http://metacpan.org/](http://metacpan.org/) using its search API.

Upon calling these API hosts, cpanm (1.6004 or later) will send the
local perl versions to the server in User-Agent string by default. You
can turn it off with `--no-report-perl-version` option. Read more
about the option with [cpanm](https://metacpan.org/pod/cpanm), and read more about the privacy policy
about this data collection at [http://cpanmetadb.plackperl.org/#privacy](http://cpanmetadb.plackperl.org/#privacy)

Fetched files are unpacked in `~/.cpanm` and automatically cleaned up
periodically.  You can configure the location of this with the
`PERL_CPANM_HOME` environment variable.

## Where does this install modules to? Do I need root access?

It installs to wherever ExtUtils::MakeMaker and Module::Build are
configured to (via `PERL_MM_OPT` and `PERL_MB_OPT`).

By default, it installs to the site\_perl directory that belongs to
your perl. You can see the locations for that by running `perl -V`
and it will be likely something under `/opt/local/perl/...` if you're
using system perl, or under your home directory if you have built perl
yourself using perlbrew or plenv.

If you've already configured local::lib on your shell, cpanm respects
that settings and modules will be installed to your local perl5
directory.

At a boot time, cpanminus checks whether you have already configured
local::lib, or have a permission to install modules to the site\_perl
directory.  If neither, i.e. you're using system perl and do not run
cpanm as a root, it automatically sets up local::lib compatible
installation path in a `perl5` directory under your home
directory.

To avoid this, run `cpanm` either as a root user, with `--sudo`
option, or with `--local-lib` option.

## cpanminus can't install the module XYZ. Is it a bug?

It is more likely a problem with the distribution itself. cpanminus
doesn't support or may have issues with distributions such as follows:

- Tests that require input from STDIN.
- Build.PL or Makefile.PL that prompts for input even when
`PERL_MM_USE_DEFAULT` is enabled.
- Modules that have invalid numeric values as VERSION (such as `1.1a`)

These failures can be reported back to the author of the module so
that they can fix it accordingly, rather than to cpanminus.

## Does cpanm support the feature XYZ of [CPAN](https://metacpan.org/pod/CPAN) and [CPANPLUS](https://metacpan.org/pod/CPANPLUS)?

Most likely not. Here are the things that cpanm doesn't do by
itself.

If you need these features, use [CPAN](https://metacpan.org/pod/CPAN), [CPANPLUS](https://metacpan.org/pod/CPANPLUS) or the standalone
tools that are mentioned.

- CPAN testers reporting. See [App::cpanminus::reporter](https://metacpan.org/pod/App%3A%3Acpanminus%3A%3Areporter)
- Building RPM packages from CPAN modules
- Listing the outdated modules that needs upgrading. See [App::cpanoutdated](https://metacpan.org/pod/App%3A%3Acpanoutdated)
- Showing the changes of the modules you're about to upgrade. See [cpan-listchanges](https://metacpan.org/pod/cpan-listchanges)
- Patching CPAN modules with distroprefs.

See [cpanm](https://metacpan.org/pod/cpanm) or `cpanm -h` to see what cpanminus _can_ do :)

# COPYRIGHT

Copyright 2010- Tatsuhiko Miyagawa

The standalone executable contains the following modules embedded.

- [CPAN::DistnameInfo](https://metacpan.org/pod/CPAN%3A%3ADistnameInfo) Copyright 2003 Graham Barr
- [local::lib](https://metacpan.org/pod/local%3A%3Alib) Copyright 2007-2009 Matt S Trout
- [HTTP::Tiny](https://metacpan.org/pod/HTTP%3A%3ATiny) Copyright 2011 Christian Hansen
- [Module::Metadata](https://metacpan.org/pod/Module%3A%3AMetadata) Copyright 2001-2006 Ken Williams. 2010 Matt S Trout
- [version](https://metacpan.org/pod/version) Copyright 2004-2010 John Peacock
- [JSON::PP](https://metacpan.org/pod/JSON%3A%3APP) Copyright 2007-2011 by Makamaka Hannyaharamitu
- [CPAN::Meta](https://metacpan.org/pod/CPAN%3A%3AMeta), [CPAN::Meta::Requirements](https://metacpan.org/pod/CPAN%3A%3AMeta%3A%3ARequirements) Copyright (c) 2010 by David Golden and Ricardo Signes
- [CPAN::Meta::YAML](https://metacpan.org/pod/CPAN%3A%3AMeta%3A%3AYAML) Copyright 2010 Adam Kennedy
- [CPAN::Meta::Check](https://metacpan.org/pod/CPAN%3A%3AMeta%3A%3ACheck) Copyright (c) 2012 by Leon Timmermans
- [File::pushd](https://metacpan.org/pod/File%3A%3Apushd) Copyright 2012 David Golden
- [parent](https://metacpan.org/pod/parent) Copyright (c) 2007-10 Max Maischein
- [Parse::PMFile](https://metacpan.org/pod/Parse%3A%3APMFile) Copyright 1995 - 2013 by Andreas Koenig, Copyright 2013 by Kenichi Ishigaki
- [String::ShellQuote](https://metacpan.org/pod/String%3A%3AShellQuote) by Roderick Schertler

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
- [irc://irc.perl.org/#cpanm](irc://irc.perl.org/#cpanm) - discussions about cpanm and its related tools

# NO WARRANTY

This software is provided "as-is," without any express or implied
warranty. In no event shall the author be held liable for any damages
arising from the use of the software.

# SEE ALSO

[CPAN](https://metacpan.org/pod/CPAN) [CPANPLUS](https://metacpan.org/pod/CPANPLUS) [pip](https://metacpan.org/pod/pip)
