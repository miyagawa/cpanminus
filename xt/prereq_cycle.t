use xt::Run;
use Test::More;

my $stdout = run qw(--showdeps Bundle::CPAN);

like last_build_log, qr/! Bundle::CPAN specifies itself as a dependency\./;

# Bundle::CPAN is not shown in the list of dependencies
unlike $stdout, qr/^Bundle::CPAN$/;

done_testing;
