use strict;
use Test::More;
use xt::Run;

# Test::More's exit.t has $^X -I../t/lib

my $local_lib = "$ENV{PERL_CPANM_HOME}/perl5";
delete $ENV{$_} for qw(PERL5LIB PERL_MM_OPT MODULEBUILDRC);
$ENV{PERL5LIB} = 'fatlib';
my @opt = ("-L", $local_lib);

run @opt, "--no-notest", "Test::Simple";
like last_build_log, qr/Successfully installed Test-Simple/;

done_testing;

