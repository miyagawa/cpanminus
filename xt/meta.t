use strict;
use Test::More;
use JSON;
use Config;
use xt::Run;

my $local_lib = "$ENV{PERL_CPANM_HOME}/perl5";
run_L "MIYAGAWA/Hash-MultiValue-0.10.tar.gz";

my $dist = (last_build_log =~ /Configuring (Hash-\S+)/)[0];

my $file = "$local_lib/lib/perl5/$Config{archname}/.meta/$dist/install.json";
ok -e $file;

open my $in, "<", $file;
my $data = JSON::decode_json(join "", <$in>);
is $data->{name}, "Hash::MultiValue";
is_deeply $data->{provides}{"Hash::MultiValue"}, { file => "Hash/MultiValue.pm", version => "0.10" };

done_testing;

