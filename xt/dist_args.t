use strict;
use Test::More;
use xt::Run;

# http://www.cpan.org/ no longer has 2.47, switch to 2.50
run 'J/JV/JV/Getopt-Long-2.50.tar.gz';
like last_build_log, qr/installed/;

run 'JV/Getopt-Long-2.50.tar.gz';
like last_build_log, qr/installed/;

run 'MIYAGAWA/Hash-MultiValue-0.13.tar.gz';
like last_build_log, qr/installed/;

run 'M/MI/MIYAGAWA/Hash-MultiValue-0.13.tar.gz';
like last_build_log, qr/installed/;

done_testing;
