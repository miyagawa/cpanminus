use xt::Run;
use Test::More;

my $local_lib = "$ENV{PERL_CPANM_HOME}/perl5";
delete $ENV{$_} for qw(PERL5LIB PERL_MM_OPT MODULEBUILDRC);
$ENV{PERL5LIB} = 'fatlib';

run("-L", $local_lib, "Hash::MultiValue"); # EUMM
run("-L", $local_lib, "Sub::Uplevel");     # M::B

ok !-e "$local_lib/man", "man page is not generated with -L";

run("-L", $local_lib, "--pod2man", "Hash::MultiValue");
run("-L", $local_lib, "--pod2man", "Sub::Uplevel");

ok -e "$local_lib/man/man3/Hash::MultiValue.3";
ok -e "$local_lib/man/man3/Sub::Uplevel.3";

done_testing;



