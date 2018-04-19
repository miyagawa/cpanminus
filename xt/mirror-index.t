use strict;
use Test::More;
use xt::Run;

run_L "--mirror-index", "xt/mirror.txt", "Hash::MultiValue";
like last_build_log, qr/installed Hash-MultiValue-0\.13/;

run_L "--mirror-index", "xt/mirror.txt", "--mirror-only", "--cascade-search", "URI::Escape~3";
unlike last_build_log, qr/Found URI::Escape version 1.60 < 3/;
like last_build_log, qr/installed URI-1.60/;

run_L "--mirror-index", "xt/mirror.txt", "--mirror-only", "TimeDate";
like last_build_log, qr/installed TimeDate-2.30/;

done_testing;
