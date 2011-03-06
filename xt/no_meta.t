use strict;
use xt::Run;
use Test::More;

run("AnyEvent::HTTP"); # META.json
like last_build_log, qr/installed AnyEvent-HTTP-/;

run("Class::Base"); # no META.yml
like last_build_log, qr/installed Class-Base-/;

done_testing;

