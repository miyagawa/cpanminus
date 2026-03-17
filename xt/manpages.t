use xt::Run;
use Test::More;

my $local_lib = "$ENV{PERL_CPANM_HOME}/perl5";

run("-L", $local_lib, "Hash::MultiValue"); # EUMM
run("-L", $local_lib, "Sub::Uplevel");     # M::B

ok !-e "$local_lib/man", "man page is not generated with -L";

ok !glob("$local_lib/man/man3/Hash::MultiValue.*");
ok !glob("$local_lib/man/man3/Sub::Uplevel.*");

run("-L", $local_lib, "--man-pages", "Hash::MultiValue");
diag last_build_log;
run("-L", $local_lib, "--man-pages", "Sub::Uplevel");
diag last_build_log;

use File::Find ();
my @found;
File::Find::find(sub { push @found, $File::Find::name if -f }, $local_lib) if -d $local_lib;
diag "Files in local_lib:\n" . join("\n", sort @found);

ok(glob("$local_lib/man/man3/Hash::MultiValue.*"));
ok(glob("$local_lib/man/man3/Sub::Uplevel.*"));

done_testing;



