use strict;
use xt::Run;
use Test::More;

run 'CJOHNSTON/Win32-SystemInfo-0.11.zip';
unlike last_build_log, qr/Bad archive/;

run 'CPAN::Test::Dummy::Perl5::Make::Zip';
like last_build_log, qr/installed/;

done_testing;
