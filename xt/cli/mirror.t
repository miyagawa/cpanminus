use strict;
use Test::More;
use xt::Run;

my($out, $err) = run_L "--mirror", "http://www.cpan.org", "--mirror-only", "--info", "Mojolicious";
like last_build_log, qr/www.cpan.org/;
like $out, qr/Mojolicious-.*\.tar\.gz/;

($out, $err) = run_L "--mirror", "http://www.cpan.org", "--from", "https://cpan.metacpan.org", "--info", "Mojolicious";
like last_build_log, qr/cpan.metacpan.org/;
like $out, qr/Mojolicious-.*\.tar\.gz/;

($out, $err) = run_L "--mirror", "http://www.cpan.org", "-M", "https://cpan.metacpan.org", "--info", "Mojolicious";
like last_build_log, qr/cpan.metacpan.org/;
like $out, qr/Mojolicious-.*\.tar\.gz/;

done_testing;
