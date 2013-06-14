use strict;
use xt::Run;
use Test::More;
use local::lib ();

run '-Uf', 'Params::Util';

my $lib = "$ENV{PERL_CPANM_HOME}/perl5";

{
    local::lib->setup_local_lib_for("$lib-shadow", 0);
    local::lib->setup_local_lib_for("$lib", 0);

    run 'Sub::Exporter';
    unlike last_build_log, qr/Installing the dependencies failed.*Params::Util/;
    like last_build_log, qr!Installing .*$lib/lib!;
}

local::lib->setup_local_lib_for($lib, local::lib::DEACTIVATE_ALL);
run 'Params::Util';

done_testing;

