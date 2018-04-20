use strict;
use Test::More;
use xt::Run;

my $output = run "--showdeps", "./testdist/MI-EUMM/";
like $output, qr/ExtUtils::MakeMaker/;

done_testing;

