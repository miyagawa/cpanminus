use strict;
use Test::More;
use xt::Run;

run "CPAN::Test::Dummy::Perl5::Developer";
like last_build_log, qr/Couldn't find module or a distribution CPAN::Test::Dummy::Perl5::Developer/;
unlike last_build_log, qr/installed CPAN-Test-Dummy-Perl5-Developer-0\.01_01/;

run '--dev', "CPAN::Test::Dummy::Perl5::Developer";
like last_build_log, qr/installed CPAN-Test-Dummy-Perl5-Developer-0\.01_01/;

run '--test-only', '--dev', 'Test::More';
like last_build_log, qr/Test-Simple-1\.00/, '2.0 is backpanned';

done_testing;
