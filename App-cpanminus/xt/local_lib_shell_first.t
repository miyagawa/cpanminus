# https://github.com/miyagawa/cpanminus/issues/263
use strict;
use lib ".";
use xt::Run;
use Test::More;
use local::lib ();

run '-Uf', 'Params::Util'; # remove from site_perl

{
    local %ENV = %ENV;
    my $lib = "$ENV{PERL_CPANM_HOME}/perl5";
    local::lib->setup_local_lib_for($lib);

    run 'Sub::Exporter';
    unlike last_build_log, qr/Installing the dependencies failed.*Params::Util/;
}

run 'Params::Util';

done_testing;
