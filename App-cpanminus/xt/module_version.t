use strict;
use Test::More;
use JSON;
use Config;
use xt::Run;

my $local_lib = "$ENV{PERL_CPANM_HOME}/perl5";

run_L "JMADLER/Log-Tiny-0.9b.tar.gz";
my $file = "$local_lib/lib/perl5/$Config{archname}/.meta/Log-Tiny-0.9b/install.json";
open my $in, "<", $file or die $!;

my $data = JSON::decode_json(join "", <$in>);
is $data->{name}, "Log::Tiny";
is $data->{version}, '0.9';

done_testing;

