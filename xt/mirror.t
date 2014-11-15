use strict;
use Test::More;
use xt::Run;

run_L "--mirror", "http://cpan.cpantesters.org", "--mirror-only", "--info", "Mojolicious";
like last_build_log, qr/cpan.cpantesters.org/;

run_L "--mirror", "http://cpan.cpantesters.org", "-M", "https://cpan.metacpan.org", "--info", "Mojolicious";
like last_build_log, qr/cpan.metacpan.org/;

done_testing;
