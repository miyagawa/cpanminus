use strict;
use xt::Run;
use Test::More;

run("AnyEvent::HTTP"); # META.json
like last_build_log, qr/installed AnyEvent-HTTP-/;

run("AnyEvent::IRC"); # META.yml being JSON
like last_build_log, qr/installed AnyEvent-IRC-/;

run("Class::Base"); # no META.yml
like last_build_log, qr/installed Class-Base-/;

done_testing;

