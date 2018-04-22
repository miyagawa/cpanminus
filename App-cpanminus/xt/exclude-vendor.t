use lib ".";
use xt::Run;
use Test::More;

# If ExtUtils::MakeMaker is installed under vendor path and not a core path,
# then --exclude-vendor will fail

use Config;
use Module::Metadata;
my $vendor_path = $Config{vendorlibexp};
my $core_path   = $Config{privlibexp};

my $core_mod = 'ExtUtils::MakeMaker';

my $core_in_vendor = 0;
if ( Module::Metadata->new_from_module( $core_mod, inc => [$vendor_path] ) ) {
    $core_in_vendor = 1;
}
if ( Module::Metadata->new_from_module( $core_mod, inc => [$core_path] ) ) {
    $core_in_vendor = 0;
}

SKIP: {
    skip 'Core modules not moved to vendor on this system' unless $core_in_vendor;

    # Something with some core dependencies
    run_L( "--exclude-vendor", "URI::Find" );

    like last_build_log, qr{Installing the dependencies failed: Module 'ExtUtils::MakeMaker'};
}

done_testing;
