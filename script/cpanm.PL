#!/usr/bin/env perl
# DEVELOPERS: Read script/build.PL in the repo how to update this
# __FATPACK__
use strict;
use lib "lib", "fatlib"; # For dev -- Auto-removed when packaging
use App::cpanminus::script;
use Parse::CPAN::Meta;

unless (caller) {
    my $app = App::cpanminus::script->new;
    $app->parse_options(@ARGV);
    $app->doit;
}
