use strict;
use Test::More;
use xt::Run;

my $local_lib = "$ENV{PERL_CPANM_HOME}/perl5";

delete $ENV{$_} for qw(PERL5LIB PERL_MM_OPT MODULEBUILDRC);
$ENV{PERL5LIB} = 'fatlib';

my @opt = ("--local-lib", $local_lib);

run @opt, "Mac::Macbinary";
like last_build_log, qr/installed/;

$ENV{PERL5LIB} = "fatlib:$local_lib/lib/perl5";

run @opt, "M/MI/MIYAGAWA/Mac-Macbinary-0.05.tar.gz";

run @opt, "Mac::Macbinary";
like last_build_log, qr/upgraded/;

run @opt, "Mac::Macbinary";
like last_build_log, qr/reinstalled/;

done_testing;

