use strict;
use Test::More;
use JSON;
use Config;
use xt::Run;

my $local_lib = "$ENV{PERL_CPANM_HOME}/perl5";

run_L '--notest', 'DSKOLL/IO-stringy-2.110.tar.gz';

my $file = "$local_lib/lib/perl5/$Config{archname}/.meta/IO-stringy-2.110/install.json";
open my $in, "<", $file or die $!;

my $data = JSON::decode_json(join "", <$in>);
is $data->{name}, "IO::Stringy";
is $data->{version}, '2.110';

# pmfiles in t/ should be excluded
ok !$data->{provides}{"Common"};
ok !$data->{provides}{"ExtUtils::TBone"};

done_testing;
