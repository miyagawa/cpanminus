use strict;
use xt::Run;
use Test::More;

run "--reinstall", "--verify", "Module::Signature";
like last_build_log, qr/Verifying the SIGNATURE/;
like last_build_log, qr/Verified OK/;

done_testing;
