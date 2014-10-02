#!/usr/bin/env PLENV_VERSION=5.8.9 perl
use strict;
use ExtUtils::Installed;

my $packlist = ExtUtils::Installed->new->packlist("ExtUtils::MakeMaker");
$packlist->validate;

for my $file (grep /\.pm$/, keys %$packlist) {
    my $mod = file_to_mod($file);
    if (my $found = has_site($mod, $file)) {
        warn "---> Found $found\n     Unlinking shadow $file\n";
        unlink $file;
    }
}

sub file_to_mod {
    my $file = shift;
    $file =~ s/^.*\/5\.\d+\.\d+\///;
    $file =~ s/\//::/g;
    $file =~ s/\.pm$//;
    return $file;
}

sub mod_to_file {
    my $mod = shift;
    $mod =~ s/::/\//g;
    return $mod . ".pm";
}

sub has_site {
    my($mod, $file) = @_;

    for my $inc (@INC) {
        my $path = "$inc/" . mod_to_file($mod);
        if (-e $path && $path ne $file) {
            return $path;
        }
    }

    return;
}




