use strict;
use xt::Run;
use Test::More;

run "KENSHAN/IO-Tee-0.64.tar.gz"; # no META.yml
like last_build_log, qr/installed IO-Tee-/;

run("AnyEvent::IRC"); # META.yml being JSON
like last_build_log, qr/installed AnyEvent-IRC-/;

run("Class::Base"); # no META.yml
like last_build_log, qr/installed Class-Base-/;

done_testing;

