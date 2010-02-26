#!/usr/bin/perl

=for developers

  NAME                          DESCRIPTION                                     repo     CPAN | wget  source  CPAN
  --------------------------------------------------------------------------------------------+--------------------
  script/cpanm.PL               frontend source                                  YES       NO |
  lib/App/cpanminus/script.pm   "the gut".                                       YES      YES |            x     x
  cpanm                         standalone, packed. #!/usr/bin/env (for cp)      YES       NO |    x
  bin/cpanm                     standalone, packed. #!perl (for EUMM)             NO      YES |            x     x

=cut

use lib "lib"; # to include the latest App/cpanminus/script.pm

open my $in,  "<", "script/cpanm.PL" or die $!;
open my $out, ">", "cpanm.tmp" or die $!;

print STDERR "Generating cpanm from script/cpanm.PL\n";

while (<$in>) {
    next if /Auto-removed/;
    s/DEVELOPERS:.*/DO NOT EDIT -- this is an auto generated file/;
    if (/^use (.*);.*# embed( lazy)?/) {
        embed_module($out, $1, $2);
    } else {
        print $out $_;
    }
}

sub embed_module {
    my($out, $mod, $lazy) = @_;

    (my $file = $mod) =~ s!::!/!g;
    my $inc = do { eval "require '$file.pm'"; $INC{"$file.pm"} };
    die $@ if $@;
    open my $in, "<", $inc or die $!;
    print STDERR "embedding $inc\n";
    print $out "# $inc (auto embedded by script/build.PL)\n";

    if ($lazy) {
        print $out "# CPANM_EMBED_BEGIN $mod\n";
    }

    my $in_pod;
    while (<$in>) {
        last if /__(?:END|DATA)__|^1;/;
        if (/^=cut/)    { $in_pod = 0; next }
        elsif (/^=\w+/) { $in_pod = 1; next }

        print $out $_ unless $in_pod;
    }

    if ($lazy) {
        print $out "# CPANM_EMBED_END $mod\n";
    }
}

close $out;

unlink "cpanm";
rename "cpanm.tmp", "cpanm";
chmod 0755, "cpanm";

END { unlink "cpanm.tmp" }
