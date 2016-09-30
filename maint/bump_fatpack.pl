#!/usr/bin/perl
# A hacked-up script to bump $VERSION in cpanm because the file is not auto-bumped by milla release process
use strict;
use warnings;

sub find_version {
    my $file = shift;

    open my $fh, "<", $file or die $!;
    while (<$fh>) {
        /package App::cpanminus;our\$VERSION="(.*?)"/ and return $1;
    }
    return;
}

my $new_ver = shift @ARGV;
my $current_ver = find_version("cpanm") or die;

system('perl-reversion', '-current', $current_ver, '-set', $new_ver, 'cpanm') == 0 or die $?;
chmod 0755, 'cpanm';
