#!/usr/bin/env perl
use strict;
use File::Path;
use File::Find;
use File::pushd;
use Tie::File;

sub rewrite_version_pm {
    my $file = shift;

    die "$file: $!" unless -e $file;
    
    tie my @file, 'Tie::File', $file or die $!;
    for (0..$#file) {
        if ($file[$_] =~ /^\s*eval "use version::vxs.*/) {
            splice @file, $_, 2, "    if (1) { # always pretend there's no XS";
            last;
        }
    }
}

sub run {
    my($fresh) = @_;

    my $dir = ".fatpack-build";
    mkpath $dir;

    {
        my $push = pushd $dir;

        open my $fh, ">cpanfile";
        print $fh <<EOF;
requires "Menlo";
EOF
        close $fh;

        $ENV{PLENV_VERSION} = "5.12.5";

        if ($fresh) {
            system "plenv", "exec", "carmel", "update";
        }

        system "plenv", "exec", "carmel", "install";
        system "plenv", "exec", "carmel", "rollout";
    }

    rmtree "fatlib";
    system "rsync", "-auv", "--chmod=u+w", "$dir/local/lib/perl5/", "fatlib/";

    use Config;
    mkpath "fatlib/version";

    for my $file ("fatlib/$Config{archname}/version.pm", glob("fatlib/$Config{archname}/version/*.pm")) {
        next if $file =~ /\bvxs\.pm$/;
        (my $target = $file) =~ s!^fatlib/$Config{archname}/!fatlib/!;
        rename $file => $target or die "$file => $target: $!";
    }

    rewrite_version_pm("fatlib/version.pm");

    rmtree("fatlib/$Config{archname}");
    rmtree("fatlib/POD2");

    find({ wanted => \&want, no_chdir => 1 }, "fatlib");
}

sub want {
    if (/\.pod$/) {
        print "rm $_\n";
        unlink $_;
    }
}

run(@ARGV);
