use strict;
use Test::More;
use xt::Run;

run 'Date::Format@2.23';
like last_build_log, qr/installed TimeDate-1.19/;

run 'CPAN::Test::Dummy::MultiPkgVer~>0.01';
like last_build_log, qr/0\.01 .* doesn't satisfy/;

run 'CPAN::Test::Dummy::MultiPkgVer::Inner@0.01';
like last_build_log, qr/0\.10 .* doesn't satisfy == 0.01/;

run 'CPAN::Test::Dummy::MultiPkgVer@0.05';
like last_build_log, qr/Finding CPAN::Test::Dummy::MultiPkgVer \(== 0\.05\) on metacpan failed/;

run '--metacpan', 'CPAN::Test::Dummy::MultiPkgVer::Inner~0.10';
like last_build_log, qr/installed CPAN-Test-Dummy-MultiPkgVer-0\.01/;

run 'CPAN::Test::Dummy::MultiPkgVer~==0.01';
like last_build_log, qr/installed CPAN-Test-Dummy-MultiPkgVer-0\.01/;

# range for v-strings
run 'App::ForkProve~>= v0.4.0, < v0.5.0';
like last_build_log, qr/installed forkprove-v0\.4\./;

run 'Try::Tiny~<0.12';
like last_build_log, qr/installed Try-Tiny-0\.11/;

run 'Try::Tiny~>=0.08';
like last_build_log, qr/installed Try-Tiny/;
unlike last_build_log, qr/You have Try::Tiny/;

run 'Try::Tiny'; # pull latest from CPAN

run '--notest', 'Try::Tiny~<0.08,!=0.07';
like last_build_log, qr/installed Try-Tiny-0.06/;

run 'Try::Tiny~>0.06, <0.08,!=0.07';
like last_build_log, qr/Finding Try::Tiny .* on metacpan failed/;
like last_build_log, qr/doesn't satisfy/;

run 'Try::Tiny';

done_testing;
