use strict;
use Test::More;
use xt::Run;

my $local_lib = "$ENV{PERL_CPANM_HOME}/perl5";

run "--local-lib", $local_lib, "--version";
ok !-e $local_lib;

done_testing;

