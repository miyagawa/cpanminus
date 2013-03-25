use strict;
use Test::More;
use xt::Run;

run '--test-only', './testdist/Requires-Perl';
unlike last_build_log, qr/Successfully/;

done_testing;

