use strict;
use Test::More;
use lib ".";
use xt::Run;

run "ExtUtils::Install";
like last_build_log, qr/Running Makefile\.PL/, "ExtUtils::Install is M::B dep, should use Makefile.PL";

run "Params::Validate";
like last_build_log, qr/Running Build\.PL/, "Build.PL only";

run "BTROTT/URI-Fetch-0.08.tar.gz";
like last_build_log, qr/Running Build\.PL/, "Build.PL and Makefile.PL";

run "CGI";
like last_build_log, qr/Running Makefile\.PL/, "Makefile.PL only";

run "Module::Build";
like last_build_log, qr/Running Build\.PL/, "Module::Build should build itself";

done_testing;

