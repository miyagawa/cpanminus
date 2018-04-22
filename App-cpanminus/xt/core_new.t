use strict;
use Test::More;
use lib ".";
use xt::Run;

if ($] >= 5.014) {
    plan skip_all => "Skip with perl $]";
}

run_L "--skip-satisfied", "CPAN::Meta";

like last_build_log, qr/installed CPAN-Meta/;

done_testing;

