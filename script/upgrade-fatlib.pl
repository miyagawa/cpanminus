#!/usr/bin/env perl
use strict;
use App::FatPacker ();
use Cwd;

my $modules = [ split /\s+/, <<MODULES ];
CPAN/DistnameInfo.pm
HTTP/Lite.pm
local/lib.pm
Module/Metadata.pm
Parse/CPAN/Meta.pm
MODULES

my $packer = App::FatPacker->new;
my @packlists = $packer->packlists_containing($modules);
$packer->packlists_to_tree(cwd . "/fatlib", \@packlists);


