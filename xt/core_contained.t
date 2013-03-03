use strict;
use Test::More;
use xt::Run;

if ($] >= 5.014) {
    plan skip_all => "Skip with perl $]";
}

run "--skip-installed", "CGI"; # this upgrades CGI in core

delete $ENV{$_} for qw(PERL5LIB PERL_MM_OPT MODULEBUILDRC);
$ENV{PERL5LIB} = 'fatlib';

run_L "--skip-installed", "CGI";
like last_build_log, qr/installed CGI/, "Upgraded modules in 'perl' should be upgraded";

run_L "--skip-installed", "CGI";
unlike last_build_log, qr/installed CGI/, "This time it's loaded from local-lib, so it's okay to skip it";

done_testing;

