# perl Makefile.PL (from git repo) copies 'cpanm' -> '{bin,share}/cpanm'
if (-e 'cpanm') {
    for my $dir ("bin", "share") {
        print STDERR "Generating $dir/cpanm from cpanm\n";
        open my $in,  "<cpanm"     or die $!;
        open my $out, ">$dir/cpanm" or die $!;
        while (<$in>) {
            s|^#!/usr/bin/env perl|#!perl|; # so MakeMaker can fix it
            print $out $_;
        }
    }
}
