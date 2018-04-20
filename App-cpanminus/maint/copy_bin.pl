# perl Makefile.PL (from git repo) copies 'cpanm' -> 'bin/cpanm'

if (-e 'cpanm') {
    for my $file ("bin/cpanm") {
        print STDERR "Generating $file from cpanm\n";
        open my $in,  "<cpanm" or die $!;
        open my $out, ">$file" or die $!;
        while (<$in>) {
            s|^#!/usr/bin/env perl|#!perl|; # so MakeMaker can fix it
            print $out $_;
        }
    }
}
