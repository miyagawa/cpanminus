use lib ".";
use xt::Run;
use Test::More;

use Config;

plan skip_all => "man pages are disabled" unless $Config{installsiteman1dir} && $Config{installsiteman3dir};

my $local_lib = "$ENV{PERL_CPANM_HOME}/perl5";

run("-L", $local_lib, "Hash::MultiValue"); # EUMM
run("-L", $local_lib, "Sub::Uplevel");     # M::B

ok !-e "$local_lib/man", "man page is not generated with -L";

ok !glob("$local_lib/man/man3/Hash::MultiValue.*");
ok !glob("$local_lib/man/man3/Sub::Uplevel.*");

run("-L", $local_lib, "--man-pages", "Hash::MultiValue");
run("-L", $local_lib, "--man-pages", "Sub::Uplevel");

ok glob("$local_lib/man/man3/Hash::MultiValue.*");
ok glob("$local_lib/man/man3/Sub::Uplevel.*");

done_testing;



