use strict;
use Test::More;
use lib ".";
use xt::Run;

plan skip_all => "disabling MYMETA tests";

use Test::Requires "Module::Signature";

run "Term::ProgressBar";
like last_build_log, qr/installed Term-ProgressBar/;
unlike last_build_log, qr/Not in MANIFEST/;

done_testing;

