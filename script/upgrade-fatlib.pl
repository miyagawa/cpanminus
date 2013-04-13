#!/usr/bin/env perl
use strict;
use App::FatPacker ();
use File::Path;
use File::Find;
use Module::CoreList;
use Cwd;

sub find_requires {
    my $file = shift;

    my %requires;
    open my $in, "<", $file or die $!;
    while (<$in>) {
        /^\s*(?:use|require) (\S+);\s*$/
          and $requires{$1} = 1;
    }

    keys %requires;
}

sub find_fatpack {
    my $file = shift;

    my @requires = find_requires($file);
    @requires = grep !is_core($_), @requires;

    my @modules = map { s!::!/!g; "$_.pm" } @requires;
    grep !in_lib($_), @modules;
}

sub in_lib {
    my $file = shift;
    -e "lib/$file";
}

sub is_core {
    my $module = shift;
    exists $Module::CoreList::version{5.008001}{$module};
}

my @modules  = find_fatpack('lib/App/cpanminus/script.pm');

my $packer = App::FatPacker->new;
my @packlists = $packer->packlists_containing(\@modules);
$packer->packlists_to_tree(cwd . "/fatlib-src", \@packlists);

use Config;
rmtree("fatlib-src/$Config{archname}");
rmtree("fatlib-src/POD2");

find({ wanted => \&want, no_chdir => 1 }, "fatlib-src");

sub want {
    if (/\.pod$/) {
        print "rm $_\n";
        unlink $_;
    }
}
