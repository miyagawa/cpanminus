use strict;
use xt::Run;
use Test::More;

run_L './testdist/TestDist-Recommend';
like last_build_log, qr/Checking if you have Try::Tiny/;
like last_build_log, qr/Checking if you have CPAN::Test::Dummy::Perl5::Build::Fails/;
like last_build_log, qr/Checking if you have Test::NoWarnings/;
unlike last_build_log, qr/Checking if you have Hash::MultiValue/;
like last_build_log, qr/::Build::Fails failed/;
like last_build_log, qr/Building .* TestDist-Recommend/;

run_L '--notest', './testdist/TestDist-Recommend';
unlike last_build_log, qr/Checking if you have Test::NoWarnings/;
like last_build_log, qr/Successfully installed TestDist-Recommend/;

done_testing;
