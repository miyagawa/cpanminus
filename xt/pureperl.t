use strict;
use xt::Run;
use Test::More;

run '--test-only', './testdist/CPAN-Dummy-Test-PP';
unlike last_build_log, qr/Pure Perl/;

run '--test-only', '--pp', './testdist/CPAN-Dummy-Test-PP';
like last_build_log, qr/Pure Perl/;

run '--test-only', '--pureperl', './testdist/CPAN-Dummy-Test-PP';
like last_build_log, qr/Pure Perl/;

done_testing;

