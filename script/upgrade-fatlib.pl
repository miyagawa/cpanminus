#!/usr/bin/env perl
use strict;
use App::FatPacker ();
use File::Path;
use Cwd;

my $modules = [ split /\s+/, <<MODULES ];
CPAN/DistnameInfo.pm
CPAN/Meta/Requirements.pm
HTTP/Tiny.pm
local/lib.pm
version.pm
Module/Metadata.pm
Module/CPANfile.pm
Parse/CPAN/Meta.pm
MODULES

my $packer = App::FatPacker->new;
my @packlists = $packer->packlists_containing($modules);
$packer->packlists_to_tree(cwd . "/fatlib", \@packlists);

use Config;
rmtree("fatlib/$Config{archname}");
