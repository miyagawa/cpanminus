use strict;
use Test::More;
use Hash::MultiValue;
use Storable qw(freeze thaw dclone);

my $l = [ qw( foo a bar baz foo b bar quux ) ];

my $hash = Hash::MultiValue->new( @$l );

is_deeply [ $hash->flatten ], $l, 'flattening works';

my $frozen = freeze $hash;
undef $hash;
$hash = thaw $frozen;
is_deeply [ $hash->flatten ], $l, '... even after deserialisation';

my $clone = dclone $hash;
is_deeply [ $clone->flatten ], $l, '... and cloning';

$clone->remove('foo');
my ($n_hash, $n_clone) = map scalar @{[$_->flatten]}, $hash, $clone;
ok $n_hash > $n_clone, '... which makes independent objects';

done_testing;
