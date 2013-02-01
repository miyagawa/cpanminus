#!/usr/bin/perl

=for developers

  NAME                          DESCRIPTION                                     repo     CPAN | wget  source  CPAN
  --------------------------------------------------------------------------------------------+--------------------
  script/cpanm.PL               frontend source                                  YES       NO |
  lib/App/cpanminus/script.pm   "the gut".                                       YES      YES |            x     x
  cpanm                         standalone, packed. #!/usr/bin/env (for cp)      YES       NO |    x
  bin/cpanm                     standalone, packed. #!perl (for EUMM)             NO      YES |            x     x

=cut

open my $in,  "<", "script/cpanm.PL" or die $!;
open my $out, ">", "cpanm.tmp" or die $!;

print STDERR "Generating cpanm from script/cpanm.PL\n";

while (<$in>) {
    next if /Auto-removed/;
    s/DEVELOPERS:.*/DO NOT EDIT -- this is an auto generated file/;
    s/.*__FATPACK__/scalar `$^X -e "use App::FatPacker -run_script" file`/e;
    print $out $_;
}

close $out;

unlink "cpanm";
rename "cpanm.tmp", "cpanm";
chmod 0755, "cpanm";

END { unlink "cpanm.tmp" }
