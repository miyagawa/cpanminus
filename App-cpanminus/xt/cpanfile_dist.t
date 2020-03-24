use strict;
use Test::More;
use lib ".";
use xt::Run;

{
    run_L "--installdeps", "./testdist/cpanfile_dist";

    like last_build_log, qr/installed Hash-MultiValue-0\.15/;
    like last_build_log, qr/installed Path-Class-0\.26/;

    like last_build_log, qr/installed Cookie-Baker-0\.08/;
    like last_build_log, qr!Fetching \Qhttp://cpan.metacpan.org/authors/id/K/KA/KAZEBURO/Cookie-Baker-0.08.tar.gz\E!;

    like last_build_log, qr/installed Try-Tiny-0\.28/;
    like last_build_log, qr!Fetching \Qhttp://backpan.perl.org/authors/id/E/ET/ETHER/Try-Tiny-0.28.tar.gz\E!;

}

{
    run_L "--installdeps", "./testdist/cpanfile_mirror";

    # downgrade from mirror
    like last_build_log, qr{Fetching \Qhttps://kiwiroy.github.io/PPAN/mock/authors/id/M/MY/MY/Hash-MultiValue-0.08.tar.gz\E};
    like last_build_log, qr/installed Hash-MultiValue-0\.08/;

    # upgrade from cpan
    like last_build_log, qr{Fetching \Qhttp://cpan.metacpan.org/authors/id/E/ET/ETHER/Try-Tiny-0.30.tar.gz\E};
    like last_build_log, qr/installed Try-Tiny-/;

    # diag last_build_log;
}

done_testing;
