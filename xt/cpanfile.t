use strict;
use Test::More;
use JSON;
use Config;
use xt::Run;

my $local_lib = "$ENV{PERL_CPANM_HOME}/perl5";

run "-L", $local_lib, "--installdeps", "--notest", "./testdist/cpanfile_app";

like last_build_log, qr/installed Hash-MultiValue-0\.10/;
like last_build_log, qr/installed Try-Tiny-0\.11/;

unlike last_build_log, qr/installed Test-Warn/, '--notest skips test requirements';

done_testing;

