use strict;
use Test::More;
use xt::Run;

{
    # dynamic_config = 0 with META.yml 1.x
    my $output = run "-l", "$ENV{PERL_CPANM_HOME}/perl5", "ETHER/Module-Install-1.16.tar.gz";
    unlike last_build_log, qr/Running Makefile\.PL/;
    ok !-e "$ENV{PERL_CPANM_HOME}/latest-build/Makefile";
    like last_build_log, qr/Successfully installed Module-Install-1.16/;
}

done_testing;

