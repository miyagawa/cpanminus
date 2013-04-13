use xt::Run;
use Test::More;

my $local_lib = "$ENV{PERL_CPANM_HOME}/perl5";
delete $ENV{$_} for qw(PERL5LIB PERL_MM_OPT MODULEBUILDRC);
$ENV{PERL5LIB} = 'fatlib-src';

# Something with some non-core dependencies
run("--self-contained", "-l", $local_lib, "URI::Find");

ok -e "$local_lib/lib/perl5/URI/Find.pm";
# Dependencies of URI::Find
ok -e "$local_lib/lib/perl5/URI.pm";

done_testing;
