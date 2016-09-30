use strict;
use Test::More;
use xt::Run;

{
    my($out, $err) = run "CPAN::Test::Dummy::Perl5::Developer";
    like $err, qr/Couldn't find module or a distribution CPAN::Test::Dummy::Perl5::Developer/;
    unlike $out, qr/CPAN-Test-Dummy-Perl5-Developer-0\.01_01/;
}

{
    my($out, $err) = run '--dev', "CPAN::Test::Dummy::Perl5::Developer";
    like $out, qr/CPAN-Test-Dummy-Perl5-Developer-0\.01_01/;
}

{
    my($out, $err) = run '--info', '--dev', 'Test::More';
    unlike $out, qr/Test-Simple-1\.005000_001/, '1.005 gets sorted based on dates';
}

done_testing;
