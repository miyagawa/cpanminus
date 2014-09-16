use xt::Run;
use Test::More;

my $local_lib = "$ENV{PERL_CPANM_HOME}/perl5";

run("-L", $local_lib, "Hash::MultiValue"); # EUMM
run("-L", $local_lib, "Sub::Uplevel");     # M::B

ok !-e "$local_lib/man", "man page is not generated with -L";

run("-L", $local_lib, "--man-pages", "Hash::MultiValue");
run("-L", $local_lib, "--man-pages", "Sub::Uplevel");

ok -e "$local_lib/man/man3/Hash::MultiValue.3";
ok -e "$local_lib/man/man3/Sub::Uplevel.3";

done_testing;



