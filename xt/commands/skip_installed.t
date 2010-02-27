use strict;
use Test::More;
use xt::Run;

run "CPAN::Test::Dummy::Perl5::Make";
run "--skip-installed", "CPAN::Test::Dummy::Perl5::Make";

my $log = last_build_log;
like $log, qr/CPAN::Test::Dummy::Perl5::Make is up to date\. \(1\.05\)/;

done_testing;

