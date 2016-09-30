#!/usr/bin/env PLENV_VERSION=5.8.9 perl
use strict;
use App::FatPacker ();
use File::Path;
use File::Find;
use Module::CoreList;
use Cwd;
use Tie::File;

$] == 5.008009 or die "Run this script as ./upgrade-fatlib.pl, rather than 'perl upgrade-fatlib.pl'\n";

# IO::Socket::IP requires newer Socket, which is C-based
$ENV{PERL_HTTP_TINY_IPV4_ONLY} = 1;

sub find_requires {
    my $file = shift;

    my %requires;
    open my $in, "<", $file or die $!;
    while (<$in>) {
        /^\s*(?:use|require) (\S+)[^;]*;\s*$/
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
    my @requires = grep !is_core(pm_to_mod($_)), grep /\.pm$/, split /\n/,
      $packer->trace(use => $modules, args => ['-e', 1]);
    push @requires, map mod_to_pm($_), @$no_trace;

    my @packlists = $packer->packlists_containing(\@requires);
    for my $packlist (@packlists) {
        print "Packing $packlist\n";
    }
    $packer->packlists_to_tree($path, \@packlists);
}

sub rewrite_version_pm {
    my $file = shift;
    tie my @file, 'Tie::File', $file or die $!;
    for (0..$#file) {
        if ($file[$_] =~ /^\s*eval "use version::vxs.*/) {
            splice @file, $_, 2, "    if (1) { # always pretend there's no XS";
            last;
        }
    }
}

sub run {
    my($upgrade) = @_;

    my @modules = grep !in_lib(mod_to_pm($_)), find_requires('lib/App/cpanminus/script.pm');

    if ($upgrade) {
        system 'cpanm', @modules;
    }

    pack_modules(cwd . "/fatlib", \@modules, [ 'local::lib', 'Exporter' ]);
    rewrite_version_pm("fatlib/version.pm");

    use Config;
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
