use strict;
use Test::More;
use lib ".";
use xt::Run;

run 'Date::Format@2.24';
like last_build_log, qr/installed TimeDate-1.20/;

# range for v-strings
run 'App::ForkProve~>= v0.4.0, < v0.5.0';
like last_build_log, qr/installed forkprove-v0\.4\./;

run 'Try::Tiny~<0.12';
like last_build_log, qr/installed Try-Tiny-0\.11/;

run 'Try::Tiny~>=0.08';
like last_build_log, qr/installed Try-Tiny/;
unlike last_build_log, qr/You have Try::Tiny/;

run 'Try::Tiny'; # pull latest from CPAN

run 'Try::Tiny~<0.08,!=0.07';
like last_build_log, qr/installed Try-Tiny-0.06/;

run 'Try::Tiny~>0.06, <0.08,!=0.07';
like last_build_log, qr/Finding Try::Tiny .* on metacpan failed/;
like last_build_log, qr/doesn't satisfy/;

run 'Try::Tiny';

done_testing;
