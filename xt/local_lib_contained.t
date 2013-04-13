use strict;
use Test::More;
use xt::Run;

delete $ENV{$_} for qw(PERL5LIB PERL_MM_OPT MODULEBUILDRC);
$ENV{PERL5LIB} = 'fatlib-src';

run_L "CGI";
like last_build_log, qr/installed FCGI/; # because FCGI is not core

done_testing;

