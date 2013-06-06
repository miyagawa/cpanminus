use xt::Run;
use Test::More;

run("./testdist/DepWithoutVersion");
like last_build_log, qr/\(undef\)/;

run "-Uf", "DepWithoutVersion";

done_testing;




