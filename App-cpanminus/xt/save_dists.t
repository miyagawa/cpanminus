use strict;
use Test::More;
use xt::Run;
use File::Temp;

my $dir = File::Temp::tempdir;

run '--test-only', '--save-dists', $dir, 'Try::Tiny@0.20';
ok -e "$dir/authors/id/D/DO/DOY/Try-Tiny-0.20.tar.gz";

run '--test-only', '--save-dists', $dir, 'http://www.cpan.org/authors/id/D/DO/DOY/Try-Tiny-0.21.tar.gz';
ok -e "$dir/authors/id/D/DO/DOY/Try-Tiny-0.21.tar.gz";

done_testing;
