use xt::Run;
use Test::More;

my $local_lib = "$ENV{PERL_CPANM_HOME}/perl5";

# Something with some non-core dependencies
run("--self-contained", "-l", $local_lib, "-n", "URI::Find");

ok -e "$local_lib/lib/perl5/URI/Find.pm";
# Dependencies of URI::Find
ok -e "$local_lib/lib/perl5/URI.pm";

done_testing;
