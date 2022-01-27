#!/usr/bin/env perl
use strict;
use CPAN::Meta;

my $meta = CPAN::Meta->load_file('META.json');
if ($meta->release_status eq 'stable') {
    system 'git', 'checkout', 'master';
    system 'git', 'merge', '--ff-only', 'maint';
    system 'git', 'push';
    system 'git', 'checkout', '-';
} else {
    warn "release_status is devel, not merging\n";
}

