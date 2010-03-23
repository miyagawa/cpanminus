use strict;
use Test::More;
use xt::Run;

my $local_lib = "$ENV{PERL_CPANM_HOME}/perl5";

delete $ENV{$_} for qw(PERL5LIB PERL_MM_OPT MODULEBUILDRC);
$ENV{PERL5LIB} = 'fatlib';

my @opt = ("-L", $local_lib);

run @opt, "CGI";
like last_build_log, qr/installed FCGI/; # because FCGI is not core

done_testing;

