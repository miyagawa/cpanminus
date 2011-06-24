use strict;
use Test::More;
use JSON;
use xt::Run;

my $local_lib = "$ENV{PERL_CPANM_HOME}/perl5";
run "-L", $local_lib, "Hash::MultiValue";

my $dist = (last_build_log =~ /Configuring (\S+)/)[0];

my $file = "$local_lib/lib/perl5/auto/meta/$dist/local.json";
ok -e $file;

open my $in, "<", $file;
my $data = JSON::decode_json(join "", <$in>);
is $data->{name}, "Hash::MultiValue";

done_testing;

