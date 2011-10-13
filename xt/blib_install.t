use strict;
use Test::More;
use JSON;
use Config;
use xt::Run;

my $local_lib = "$ENV{PERL_CPANM_HOME}/perl5";
run "-L", $local_lib, "FLORA/FCGI-0.74.tar.gz";

my $file = "$local_lib/lib/perl5/$Config{archname}/.meta/FCGI-0.74/install.json";

open my $in, "<", $file or die $!;

my $data = JSON::decode_json(join "", <$in>);
is $data->{name}, "FCGI";
ok exists $data->{provides}{FCGI};

done_testing;

