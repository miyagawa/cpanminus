use strict;
use xt::Run;
use Test::More;

plan skip_all => "only on 5.10.1" if $] != 5.010001;

run 'http://backpan.perl.org/authors/id/D/DA/DAGOLDEN/Module-Build-0.340201.tar.gz';
like last_build_log, qr/installed Module-Build/;

my ($stdout, $stderr, $exit) = run 'Hook::LexWrap@0.24';
unlike last_build_log, qr/Failed to upconvert metadata/;
unlike $stderr, qr/Failed to upconvert metadata/;

done_testing;



