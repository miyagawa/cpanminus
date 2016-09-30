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

sub generate_file {
    my($base, $target, $fatpack, $shebang_replace) = @_;

    open my $in,  "<", $base or die $!;
    open my $out, ">", "$target.tmp" or die $!;

    print STDERR "Generating $target from $base\n";

    while (<$in>) {
        next if /Auto-removed/;
        s|^#!/usr/bin/env perl|$shebang_replace| if $shebang_replace;
        s/DEVELOPERS:.*/DO NOT EDIT -- this is an auto generated file/;
        s/.*__FATPACK__/$fatpack/;
        print $out $_;
    }

    close $out;

    unlink $target;
    rename "$target.tmp", $target;
}

my $fatpack = `fatpack file`;

mkdir ".build", 0777;
system qw(cp -r fatlib lib .build/);

my $fatpack_compact = do {
    my $dir = pushd '.build';

    my @files;
    my $want = sub {
        push @files, $_ if /\.pm$/;
    };

    find({ wanted => $want, no_chdir => 1 }, "fatlib", "lib");
    system 'perlstrip', '--cache', '-v', @files;

    `fatpack file`;
};

generate_file('script/cpanm.PL', "cpanm", $fatpack_compact);
generate_file('script/cpanm.PL', "fatpacked/App/cpanminus/fatscript.pm", $fatpack, 'package App::cpanminus::fatscript;');
chmod 0755, "cpanm";

END {
    unlink $_ for "cpanm.tmp", "fatpacked/App/cpanminus/fatscript.pm.tmp";
    system "rm", "-r", ".build";
}
