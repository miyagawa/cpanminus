use xt::Run;
use Test::More;

run("./testdist/DepWithoutVersion");
like last_build_log, qr/\(undef\)/;

system "pm-uninstall", "-fn", "DepWithoutVersion";

done_testing;




