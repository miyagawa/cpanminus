use strict;
use xt::Run;
use Test::More;

plan skip_all => "only on 5.8.9" if $] != 5.008009;

run '-Uf', 'Module::Build';

run 'Algorithm::C3';
like last_build_log, qr/installed Algorithm-C3/;

done_testing;



