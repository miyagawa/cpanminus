#!/usr/bin/perl
use strict;
use File::Find;

=for developers

  NAME                          DESCRIPTION                                     repo     CPAN | wget  source  CPAN
  --------------------------------------------------------------------------------------------+--------------------
  script/cpanm.PL               frontend source                                  YES       NO |
  lib/App/cpanminus/script.pm   "the gut".                                       YES      YES |            x     x
  cpanm                         standalone, packed. #!/usr/bin/env (for cp)      YES       NO |    x
  bin/cpanm                     standalone, packed. #!perl (for EUMM)             NO      YES |            x     x

=cut

system 'cp', '-r', 'fatlib-src', 'fatlib';

my $want = sub {
    if (/\.pm$/) {
        print "perlstrip $_\n";
        system 'perlstrip', $_;
    }
};

find({ wanted => $want, no_chdir => 1 }, "fatlib");

open my $in,  "<", "script/cpanm.PL" or die $!;
open my $out, ">", "cpanm.tmp" or die $!;

print STDERR "Generating cpanm from script/cpanm.PL\n";

while (<$in>) {
    next if /Auto-removed/;
    s/DEVELOPERS:.*/DO NOT EDIT -- this is an auto generated file/;
    s/.*__FATPACK__/`fatpack file`/e;
    print $out $_;
}

close $out;

unlink "cpanm";
rename "cpanm.tmp", "cpanm";
chmod 0755, "cpanm";
system "rm", "-r", "fatlib";

END { unlink "cpanm.tmp" }
