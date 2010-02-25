my $author = -d '.git' && `git remote -v` =~ /git\@github/;
print STDERR "Running as an author mode!\n";

# Author: perl Makefile.PL PACK=1 packs 'script/cpanm.PL' -> 'cpanm'
if ($author) {
    shift @ARGV;
    system "script/build.PL" and die $?;
}

# perl Makefile.PL (from git repo) copies 'cpanm' -> 'bin/cpanm'
if ($author or !-e 'bin/cpanm') {
    print STDERR "Generating bin/cpanm from cpanm\n";
    open my $in,  "<cpanm"     or die $!;
    open my $out, ">bin/cpanm" or die $!;
    while (<$in>) {
        s|^#!/usr/bin/env perl|#!perl|; # so MakeMaker can fix it
        print $out $_
    }
}

use ExtUtils::MakeMaker;
WriteMakefile(
    NAME => 'App::cpanminus',
    VERSION_FROM => "lib/App/cpanminus.pm",
    ABSTRACT => 'Get, unpack, build and install modules from CPAN.',
    PREREQ_PM => {
        'Module::Build' => 0.28,
        'ExtUtils::MakeMaker' => 6.31,
        'ExtUtils::Install' => 1.43,
        LWP => 5.828,
    },
    LICENSE => 'perl',
    EXE_FILES => [ 'bin/cpanm' ],
);
