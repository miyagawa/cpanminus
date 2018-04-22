use strict;
use lib ".";
use xt::Run;
use Test::More;
use local::lib ();

run '-Uf', 'Params::Util';

my $lib = "$ENV{PERL_CPANM_HOME}/perl5";

{
    local::lib->setup_local_lib_for("$lib-shadow");
    local::lib->setup_local_lib_for("$lib");

    run 'Sub::Exporter';
    unlike last_build_log, qr/Installing the dependencies failed.*Params::Util/;
    like last_build_log, qr!Installing .*$lib/lib!;
}

local::lib->deactivate($lib);
run 'Params::Util';

done_testing;

