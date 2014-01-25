use strict;
use Test::More;
use xt::Run;

run "CPAN::Test::Dummy::Perl5::Make";
run "--skip-installed", "CPAN::Test::Dummy::Perl5::Make";

like last_build_log, qr/CPAN::Test::Dummy::Perl5::Make is up to date\. \(1\.05\)/;

run "CPAN::Test::Dummy::Perl5::Make";
like last_build_log, qr/reinstalled/;

run_L "MIYAGAWA/Hash-MultiValue-0.03.tar.gz";
run_L '--skip-installed', "./testdist/Hash-MultiValue-0.03.tar.gz";
like last_build_log, qr/Hash::MultiValue is up to date\. \(0\.03\)/;

done_testing;

