# NAME

Menlo - A CPAN client

# DESCRIPTION

Menlo is a backend for _cpanm 2.0_, developed with the goal to
replace [cpanm](https://metacpan.org/pod/cpanm) internals with a set of modules that are more
flexible, extensible and easier to use.

# COMPATIBILITY

Menlo is developed within [cpanm](https://metacpan.org/pod/cpanm) git repository at `Menlo`
subdirectory.

Menlo::CLI::Compat started off as a copy of App::cpanminus::script,
but will go under a big refactoring to extract all the bits out of
it. Hopefully the end result will be just a shim and translation layer
to interpret command line options.

# MOTIVATION

cpanm has been a popular choice of CPAN package installer for many
developers, because it is lightweight, fast, and requires no
configuration in most environments.

Meanwhile, the way cpanm has been implemented (one God class, and all
modules are packaged in one script with fatpacker) makes it difficult
to extend, or modify the behaviors at a runtime, unless you decide to
fork the code or monkeypatch its hidden backend class.

cpanm also has no scriptable API or hook points, which means if you
want to write a tool that works with cpanm, you basically have to work
around its behavior by writing a shell wrapper, or parsing the output
of its standard out or a build log file.

Menlo will keep the best aspects of cpanm, which is dependencies free,
configuration free, lightweight and fast to install CPAN modules. At
the same time, it's impelmented as a standard perl module, available
on CPAN, and you can extend its behavior by either using its modular
interfaces, or writing plugins to hook into its behaviors.

# FAQ

- Dependencies free? I see many prerequisites in Menlo.

    Menlo is a set of libraries and uses non-core CPAN modules as its
    dependencies. App-cpanminus distribution embeds Menlo and all of its
    runtime dependencies into a fatpacked binary, so that you can install
    App-cpanminus or Menlo without having any CPAN client to begin with.

- Is Menlo a new name for cpanm?

    Right now it's just a library name, but I'm comfortable calling this a
    new package name for cpanm 2's backend.

# AUTHOR

Tatsuhiko Miyagawa <miyagawa@bulknews.net>

# COPYRIGHT

2010- Tatsuhiko Miyagawa

# LICENSE

This software is licensed under the same terms as Perl.

# SEE ALSO

[cpanm](https://metacpan.org/pod/cpanm)
