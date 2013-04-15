#!/usr/bin/env perl
use strict;
use File::pushd;
use File::Find;

=for developers

  NAME                          DESCRIPTION                                     repo     CPAN | wget  source  CPAN
  --------------------------------------------------------------------------------------------+--------------------
  script/cpanm.PL               frontend source                                  YES       NO |
  lib/App/cpanminus/script.pm   "the gut".                                       YES       NO |            x     
  cpanm                         standalone, packed. #!/usr/bin/env (for cp)      YES       NO |    x
  bin/cpanm                     standalone, packed. #!perl (for EUMM)             NO      YES |            x     x

=cut

mkdir ".build", 0777;
system qw(cp -r fatlib lib .build/);

my $fatpack = do {
    my $dir = pushd '.build';

    my $want = sub {
        if (/\.pm$/) {
            print "perlstrip $_\n";
            system 'perlstrip', '--cache', $_;
        }
    };

    find({ wanted => $want, no_chdir => 1 }, "fatlib", "lib");
    `fatpack file`;
};

open my $in,  "<", "script/cpanm.PL" or die $!;
open my $out, ">", "cpanm.tmp" or die $!;

print STDERR "Generating cpanm from script/cpanm.PL\n";

while (<$in>) {
    next if /Auto-removed/;
    s/DEVELOPERS:.*/DO NOT EDIT -- this is an auto generated file/;
    s/.*__FATPACK__/$fatpack/;
    print $out $_;
}

close $out;

unlink "cpanm";
rename "cpanm.tmp", "cpanm";
chmod 0755, "cpanm";

END {
    unlink "cpanm.tmp";
    system "rm", "-r", ".build";
}
