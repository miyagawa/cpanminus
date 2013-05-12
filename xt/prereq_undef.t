use xt::Run;
use Test::More;

run("./testdist/DepWithoutVersion");
like last_build_log, qr/\(undef\)/;

system "cpanm", "-Uf", "DepWithoutVersion";

done_testing;




