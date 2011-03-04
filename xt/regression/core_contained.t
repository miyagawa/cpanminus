use strict;
use Test::More;
use xt::Run;

run "--skip-installed", "CGI"; # this upgrades CGI in core

my $local_lib = "$ENV{PERL_CPANM_HOME}/perl5";
delete $ENV{$_} for qw(PERL5LIB PERL_MM_OPT MODULEBUILDRC);
$ENV{PERL5LIB} = 'fatlib';
my @opt = ("-L", $local_lib);

run @opt, "--skip-installed", "-n", "CGI";
like last_build_log, qr/installed CGI/, "Upgraded modules in 'perl' should be upgraded";

run @opt, "--skip-installed", "-n", "CGI";
unlike last_build_log, qr/installed CGI/, "This time it's loaded from local-lib, so it's okay to skip it";

done_testing;

