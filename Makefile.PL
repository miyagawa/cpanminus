=for developers

If you're a developer, Makefile.PL will pack `cpanm` from
script/cpanm.PL and then copy that file to `bin/cpanm`.

You can pretend to be an author by running it with:

  perl Makefile.PL --author

Do not commit the changes to `cpanm` standalone executable. We only
commit changes to this file whenever we tag a new CPAN release.

=cut

my $author = ((grep{ $_ eq '--author' } @ARGV) or -d '.git' && `git remote -v` =~ /git\@github/);
print STDERR "Running as an author mode!\n" if $author;

# Author: perl Makefile.PL packs 'script/cpanm.PL' -> 'cpanm'
if ($author) {
    shift @ARGV;
    system $^X, "-I", "xt/lib", "script/build.PL" and die $?;
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
        ($ENV{PERL5_CPAN_IS_RUNNING} || $ENV{PERL5_CPANPLUS_IS_RUNNING}) ? (LWP => 5.828) : (),
    },
    LICENSE => 'perl',
    EXE_FILES => [ 'bin/cpanm' ],
);
