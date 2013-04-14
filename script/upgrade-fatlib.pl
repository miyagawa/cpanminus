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

sub mod_to_pm {
    local $_ = shift;
    s!::!/!g;
    "$_.pm";
}

sub pm_to_mod {
    local $_ = shift;
    s!/!::!g;
    s/\.pm$//;
    $_;
}

sub in_lib {
    my $file = shift;
    -e "lib/$file";
}

sub is_core {
    my $module = shift;
    exists $Module::CoreList::version{5.008001}{$module};
}

sub exclude_modules {
    my($modules, $except) = @_;
    my %exclude = map { $_ => 1 } @$except;
    [ grep !$exclude{$_}, @$modules ];
}

sub pack_modules {
    my($path, $modules, $no_trace) = @_;

    $modules = exclude_modules($modules, $no_trace);

    my $packer = App::FatPacker->new;
    my @requires = grep !is_core(pm_to_mod($_)), split /\n/,
      $packer->trace(use => $modules, args => ['/dev/null']);
    push @requires, map mod_to_pm($_), @$no_trace;

    my @packlists = $packer->packlists_containing(\@requires);
    $packer->packlists_to_tree($path, \@packlists);
}

my @modules = grep !in_lib(mod_to_pm($_)), find_requires('lib/App/cpanminus/script.pm');
pack_modules(cwd . "/fatlib-src", \@modules, [ 'local::lib' ]);

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
