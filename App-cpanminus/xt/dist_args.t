use strict;
use Test::More;
use lib ".";
use xt::Run;

run 'J/JV/JV/Getopt-Long-2.47.tar.gz';
like last_build_log, qr/installed/;

run 'JV/Getopt-Long-2.47.tar.gz';
like last_build_log, qr/installed/;

run 'MIYAGAWA/Hash-MultiValue-0.13.tar.gz';
like last_build_log, qr/installed/;

run 'M/MI/MIYAGAWA/Hash-MultiValue-0.13.tar.gz';
like last_build_log, qr/installed/;

done_testing;
