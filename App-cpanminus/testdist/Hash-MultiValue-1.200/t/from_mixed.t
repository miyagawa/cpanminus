use strict;
use Test::More;
use Hash::MultiValue;

my $hash = Hash::MultiValue->from_mixed({
    foo => [ 'a', 'b' ],
    bar => 'baz',
    baz => 33,
});

is "$hash->{foo}", 'b';
is ref $hash->{foo}, '';
my @foo = $hash->get_all('foo');
is_deeply \@foo, [ 'a', 'b' ];
is_deeply [ sort keys %$hash ], [ 'bar', 'baz', 'foo' ];
is $hash->{baz} + 2, 35;

done_testing;
