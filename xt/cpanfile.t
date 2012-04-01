use strict;
use Test::More;
use JSON;
use Config;
use xt::Run;

my $local_lib = "$ENV{PERL_CPANM_HOME}/perl5";

run "-L", $local_lib, "--installdeps", "./testdist/cpanfile_app";

like last_build_log, qr/installed Hash-MultiValue/;
unlike last_build_log, qr/installed Test-Warn/;

done_testing;

