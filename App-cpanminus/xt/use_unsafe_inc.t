use strict;
use Test::More;
use lib ".";
use xt::Run;

{
    run_L "--dev", "--no-notest", "CPAN::Test::Dummy::Perl5::UseUnsafeINC::Fail";
    like last_build_log, qr/Distribution opts in x_use_unsafe_inc: 0/;
    unlike last_build_log, qr/Do not load me/;
    like last_build_log, qr/installed CPAN-Test-Dummy-Perl5-UseUnsafeINC-Fail/;
}

{
    run_L "--dev", "--no-notest", "CPAN::Test::Dummy::Perl5::UseUnsafeINC::One";
    like last_build_log, qr/Distribution opts in x_use_unsafe_inc: 1/;
    unlike last_build_log, qr/Can't locate t.Foo\.pm/;
    like last_build_log, qr/installed CPAN-Test-Dummy-Perl5-UseUnsafeINC-One/;
}

done_testing;
