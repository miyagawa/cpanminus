use strict;
use Test::More;
use xt::Run;

my $local_lib = "$ENV{PERL_CPANM_HOME}/perl5";

run "-L", $local_lib, 'Lingua::Romana::Perligata@0.50';
like last_build_log, qr/installed Lingua-Romana-Perligata-0.50/;

run "-L", $local_lib, 'Hash::MultiValue@0.01';
like last_build_log, qr/Found Hash::MultiValue .* doesn't satisfy == 0.01/;

done_testing;
