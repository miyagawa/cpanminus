=for developers

If you're a developer, Makefile.PL will pack `cpanm` from
script/cpanm.PL and then copy that file to `bin/cpanm`.

You can pretend to be an author by running it with:

  perl Makefile.PL --author

You should install local::lib, Parse::CPAN::Meta, Module::Metadata,
App::FatPacker and HTTP::Tiny before doing so.

Do not commit the changes to `cpanm` standalone executable. We only
commit changes to this file whenever we tag a new CPAN release.

=cut

my $author = ((grep{ $_ eq '--author' } @ARGV) or -d '.git' && `git remote -v` =~ /git\@github/);
print STDERR "Running as an author mode!\n" if $author;

# Author: perl Makefile.PL packs 'script/cpanm.PL' -> 'cpanm'
if ($author) {
    shift @ARGV;
    system $^X, "script/build.PL" and die $?;
}

# perl Makefile.PL (from git repo) copies 'cpanm' -> 'bin/cpanm'
if (-e 'cpanm') {
    print STDERR "Generating bin/cpanm from cpanm\n";
    open my $in,  "<cpanm"     or die $!;
    open my $out, ">bin/cpanm" or die $!;
    while (<$in>) {
        s|^#!/usr/bin/env perl|#!perl|; # so MakeMaker can fix it
        print $out $_
    }
}

use ExtUtils::MakeMaker;

my %args = (
    NAME => 'App::cpanminus',
    VERSION_FROM => "lib/App/cpanminus.pm",
    ABSTRACT => 'Get, unpack, build and install modules from CPAN.',
    PREREQ_PM => {
        'Module::Build' => 0.36,
        'ExtUtils::MakeMaker' => 6.31,
        'ExtUtils::Install' => 1.46,
    },
    LICENSE => 'perl',
    EXE_FILES => [ 'bin/cpanm' ],
);

my $eummv = eval ($ExtUtils::MakeMaker::VERSION);
if ($eummv >= 6.45) {
    $args{META_MERGE} = {
        resources => {
            repository => 'git://github.com/miyagawa/cpanminus.git',
            bugtracker => 'https://github.com/miyagawa/cpanminus/issues',
        },
    };
}

WriteMakefile(%args);
