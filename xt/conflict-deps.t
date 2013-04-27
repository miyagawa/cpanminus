use strict;
use xt::Run;
use Test::More;

run '-U', '-f', 'AnyEvent::HTTP::LWP::UserAgent';

run 'Facebook::Graph@1.0500';
like last_build_log, qr/Found AnyEvent::HTTP::LWP::UserAgent .* which doesn't satisfy 0\.8/;

run 'AnyEvent::HTTP::LWP::UserAgent@0.10';
like last_build_log, qr/installed AnyEvent-HTTP-LWP-UserAgent-0\.10/;

run 'Facebook::Graph@1.0500';
like last_build_log, qr/Found AnyEvent::HTTP::LWP::UserAgent .* which doesn't satisfy 0\.8/;

done_testing;


