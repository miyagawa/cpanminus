{
    print STDERR "Generating bin/cpanm\n";
    open my $out, ">bin/cpanm" or die $!;
    open my $in,  "<cpanm"     or die $!;
    while (<$in>) {
        s|^#!/usr/bin/env perl|#!perl|; # so MakeMaker can fix it
        print $out $_
    }
    close $out;
}

use ExtUtils::MakeMaker;
WriteMakefile(
    NAME => 'App::cpanminus',
    VERSION_FROM => "lib/App/cpanminus.pm",
    ABSTRACT => 'Get, unpack, build and install modules from CPAN.',
    PREREQ_PM => {
        'LWP' => 0,
        'Module::Build' => 0,
    },
    EXE_FILES => [ 'bin/cpanm' ],
    clean => { FILES => 'bin/cpanm' },
);
