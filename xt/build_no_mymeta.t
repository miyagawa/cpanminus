use strict;
use xt::Run;
use Test::More;

plan skip_all => "only on 5.10.1" if $] != 5.010001;

run '-n', 'Module::Build@0.340201';
like last_build_log, qr/installed Module-Build/;

run 'Hook::LexWrap';
unlike last_build_log, qr/Failed to upconvert metadata/;

done_testing;



