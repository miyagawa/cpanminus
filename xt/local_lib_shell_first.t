# https://github.com/miyagawa/cpanminus/issues/263
use strict;
use xt::Run;
use Test::More;
use local::lib ();

run '-Uf', 'Params::Util'; # remove from site_perl

my $lib = "$ENV{PERL_CPANM_HOME}/perl5";
local::lib->setup_env_hash_for($lib, 0);

run 'Sub::Exporter';
unlike last_build_log, qr/Installing the dependencies failed.*Params::Util/;

local::lib->setup_env_hash_for($lib, 1); # deactivate
run 'Params::Util';

done_testing;
