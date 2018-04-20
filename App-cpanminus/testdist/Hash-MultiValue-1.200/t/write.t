use strict;
use Test::More;
use Hash::MultiValue;

my $hash = Hash::MultiValue->new(
    foo => 'a',
    foo => 'b',
    bar => 'baz',
);

$hash->add(baz => 33);
is $hash->{baz}, 33;

my $new_hash = $hash->clone;
is_deeply $hash, $new_hash;

$new_hash->add('xyz' => 'zzy');
$hash->remove('foo');

is_deeply [ sort keys %$hash ], [ qw(bar baz) ];
is_deeply [ $hash->keys ], [ qw(bar baz) ];

$hash->add('bar'); # no-op add
is $hash->{'bar'}, 'baz';

$hash->clear;
is_deeply $hash, {};
isa_ok $hash, 'Hash::MultiValue';


done_testing;
