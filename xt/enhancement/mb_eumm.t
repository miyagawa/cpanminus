use strict;
use Test::More;
use xt::Run;

# NOTE these tests take so long time, so added --notest here

run "--notest", "ExtUtils::Install";
like last_build_log, qr/Running Makefile\.PL/, "ExtUtils::Install is M::B dep, should use Makefile.PL";

run "--notest", "Params::Validate";
like last_build_log, qr/Running Build\.PL/, "Build.PL only";

run "--notest", "URI::Fetch";
like last_build_log, qr/Running Build\.PL/, "Build.PL and Makefile.PL";

run "--notest", "CGI";
like last_build_log, qr/Running Makefile\.PL/, "Makefile.PL only";

run "--notest", "Module::Build";
like last_build_log, qr/Running Build\.PL/, "Module::Build should build itself";

done_testing;

