use strict;
use xt::Run;
use Test::More;

run 'CJOHNSTON/Win32-SystemInfo-0.11.zip';
unlike last_build_log, qr/Bad archive/;

done_testing;
