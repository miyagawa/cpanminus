use strict;
use Test::More;
use Hash::MultiValue;

my @l = qw( foo a bar baz foo b bar quux );

my $hash = Hash::MultiValue->new( @l );

$hash->set(foo => 1 .. 3);
is_deeply [ $hash->flatten ], [ qw( foo 1 bar baz foo 2 bar quux foo 3 ) ], 'more items than before';
is $hash->{'foo'}, 3;

$hash->add(bar => 'qux');
$hash->set(bar => 'a' .. 'c');
is_deeply [ $hash->flatten ], [ qw( foo 1 bar a foo 2 bar b foo 3 bar c ) ], 'exactly as many items as before';
is $hash->{'bar'}, 'c';

$hash->set(foo => qw(x y));
is_deeply [ $hash->flatten ], [ qw( foo x bar a foo y bar b bar c ) ], 'fewer items than before';
is $hash->{'foo'}, 'y';

$hash->set('bar');
is_deeply [ $hash->flatten ], [ qw( foo x foo y ) ], 'no items';
is $hash->{'bar'}, undef;

isa_ok $hash, 'Hash::MultiValue';

done_testing;
