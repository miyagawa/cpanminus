use strict;
use Test::More;
use lib ".";
use xt::Run;

run "Perl6::Str~v0.0.4";
like last_build_log, qr/installed Perl6-Str-v0\.0\./;

done_testing;
