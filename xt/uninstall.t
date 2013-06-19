use strict;
use xt::Run;
use Test::More;
use Module::Metadata;

run '--uninstall', 'NonExistent';
like last_build_log, qr/is not found/;

run '--uninstall', 'Pod::Usage';
like last_build_log, qr/is not found/, 'Core module in perl path';

run '--uninstall', 'utf8';
like last_build_log, qr/is not found/;

run 'Hash::MultiValue';
run '--uninstall', '-f', 'Hash::MultiValue';
like last_build_log, qr!Unlink.*/Hash/MultiValue\.pm!;

run_L 'Hash::MultiValue';
run_L '--uninstall', '-f', 'Hash::MultiValue';
like last_build_log, qr!Unlink.*$ENV{PERL_CPANM_HOME}.*/Hash/MultiValue\.pm!;

# shadow installs
run 'Hash::MultiValue';
run_L 'Hash::MultiValue';
run_L '--uninstall', '-f', 'Hash::MultiValue';
like last_build_log, qr!Unlink.*$ENV{PERL_CPANM_HOME}.*/Hash/MultiValue\.pm!;
unlike last_build_log, qr!Unlink.*site_perl.*/Hash/MultiValue\.pm!;

run_L 'Module::CoreList';
run_L '--uninstall', '-f', 'Module::CoreList';
like last_build_log, qr!Unlink.*$ENV{PERL_CPANM_HOME}.*/Module/CoreList\.pm!;
like last_build_log, qr!Unlink.*$ENV{PERL_CPANM_HOME}.*/bin/corelist!;

# older perl installs dual-life modules to perl lib
if ($] >= 5.012) {
    run 'Module::CoreList';
    run '-U', '-f', 'Module::CoreList';
    unlike last_build_log, qr!not found!, "Dual-life can be uninstalled";
    like last_build_log, qr!Unlink.*/Module/CoreList\.pm!;
    unlike last_build_log, qr!Unlink.*/bin/corelist!, "Do not uninstall bin/ when it is shared";

    my $mod = Module::Metadata->new_from_module("Module::CoreList");
    ok $mod;
    unlike $mod->filename, qr/site_perl/;
}

run '-n', 'App::Ack';
run '-U', '-f', 'App::Ack';
like last_build_log, qr!Unlink:.*bin/ack!, "Uninstall bin/ when it is not shared";

run '-n', $_ for qw( Hash::MultiValue Module::CoreList App::Ack );

done_testing;
