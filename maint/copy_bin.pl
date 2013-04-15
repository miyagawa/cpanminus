# perl Makefile.PL (from git repo) copies 'cpanm' -> 'bin/cpanm'
if (-e 'cpanm') {
    print STDERR "Generating bin/cpanm from cpanm\n";
    open my $in,  "<cpanm"     or die $!;
    open my $out, ">bin/cpanm" or die $!;
    while (<$in>) {
        s|^#!/usr/bin/env perl|#!perl|; # so MakeMaker can fix it
        print $out $_;
    }
}
