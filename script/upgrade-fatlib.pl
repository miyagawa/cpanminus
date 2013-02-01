#!/usr/bin/env perl
use strict;
use App::FatPacker ();
use File::Path;
use File::Find;
use Cwd;

my $modules = [ split /\s+/, <<MODULES ];
CPAN/DistnameInfo.pm
Parse/CPAN/Meta.pm
local/lib.pm
HTTP/Tiny.pm
Module/Metadata.pm
version.pm
JSON/PP.pm
CPAN/Meta.pm
CPAN/Meta/Requirements.pm
MODULES

my $packer = App::FatPacker->new;
my @packlists = $packer->packlists_containing($modules);
$packer->packlists_to_tree(cwd . "/fatlib", \@packlists);

use Config;
rmtree("fatlib/$Config{archname}");
rmtree("fatlib/POD2");

find({ wanted => \&want, no_chdir => 1 }, "fatlib");

sub want {
    if (/\.pod$/) {
        unlink $_;
    } elsif (/\.pm$/) {
        system 'podstrip', $_, "$_.tmp";
        rename "$_.tmp", $_;
    }
}
