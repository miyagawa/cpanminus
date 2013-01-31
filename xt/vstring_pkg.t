use strict;
use Test::More;
use xt::Run;

my $local_lib = "$ENV{PERL_CPANM_HOME}/perl5";
run "-L", $local_lib, "--notest", "Perl6::Str~v0.0.4";
like last_build_log, qr/installed Perl6-Str-v0\.0\./;

done_testing;
