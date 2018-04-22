use strict;
use Test::More;
use lib ".";
use xt::Run;

run '--test-only', './testdist/Requires-Perl';
like last_build_log, qr/Bailing out/;
like last_build_log, qr/Needs perl/;
unlike last_build_log, qr/Successfully/;

run '--test-only', './testdist/Requires-Perl2';
like last_build_log, qr/Bailing out/;
like last_build_log, qr/Needs perl/;

done_testing;
