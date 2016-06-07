use lib ".";
use xt::Run;
use Test::More;

my $stdout = run qw(--showdeps ./testdist/SelfDep);

like last_build_log, qr/! SelfDep specifies its own modules as dependencies\./;
like last_build_log, qr/! Omitting.*SelfDep.*SelfDep::Also/;

# Bundle::CPAN is not shown in the list of dependencies
unlike $stdout, qr/^SelfDep$/;

done_testing;
