# perl Makefile.PL (from git repo) copies 'cpanm' -> 'bin/cpanm'

my $header = {
    "bin/cpanm" => "#!perl", # so MakeMaker can fix it
    "fatpacked/App/cpanminus/fatscript.pm" => "package App::cpanminus::fatscript;",
};

if (-e 'cpanm') {
    for my $file ("bin/cpanm", "fatpacked/App/cpanminus/fatscript.pm") {
        print STDERR "Generating $file from cpanm\n";
        open my $in,  "<cpanm" or die $!;
        open my $out, ">$file" or die $!;
        while (<$in>) {
            s|^#!/usr/bin/env perl|$header->{$file}|;
            print $out $_;
        }
    }
}
