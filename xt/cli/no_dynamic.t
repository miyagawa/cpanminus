use strict;
use Test::More;
use xt::Run;

{
    # dynamic_config = 0, has configure_requires for MBT, and has no cpanfile
    my $output = run_L "--showdeps", "ETHER/Plack-Middleware-LogErrors-0.002.tar.gz";
    unlike last_build_log, qr/Working on Module::Build::Tiny/;
    warn last_build_log;
    like $output, qr/Plack::Middleware/;
}

done_testing;

