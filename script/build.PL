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

my(@embed, @code);

open my $in,  "<", "script/cpanm.PL" or die $!;
open my $out, ">", "cpanm" or die $!;

print STDERR "Generating cpanm from script/cpanm.PL\n";

while (<$in>) {
    next if /Auto-removed/;
    s/DEVELOPERS:.*/DO NOT EDIT -- this is an auto generated file/;
    /^#/ and print $out $_;
    if (/^use (.*);.*embed/) {
        push @embed, $1;
    } else {
        push @code, $_;
    }
}

for my $embed (@embed) {
    my $file = $embed;
    $file =~ s!::!/!g;
    my $inc = do { eval "require '$file.pm'"; $INC{"$file.pm"} };
    die $@ if $@;
    open my $mod, "<", $inc or die $!;
    print STDERR "embedding $inc\n";
    print $out "# $inc (auto embedded by script/build.PL)\n";
    while (<$mod>) {
        last if /__(?:END|DATA)__|^1;/;
        print $out $_;
    }
}

print $out "package main;\n";
for my $code (@code) {
    print $out $code;
}


chmod 0755, "cpanm";





