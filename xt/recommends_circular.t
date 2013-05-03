use strict;
use xt::Run;
use Test::More;

run_L '--with-recommends', 'URI';
like last_build_log, qr/Successfully installed Business-ISBN-\d/;
unlike last_build_log, qr/Installing the dependencies failed: Module 'URI' is not installed/;

done_testing;
