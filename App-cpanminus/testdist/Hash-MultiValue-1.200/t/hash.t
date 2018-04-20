use strict;
use Test::More;
use Hash::MultiValue;

my $hash = Hash::MultiValue->new(
    foo => 'a',
    foo => 'b',
    bar => 'baz',
    baz => 33,
);

{
    my $foo = $hash->as_hashref;
    is ref $foo, 'HASH';
    is scalar keys %$foo, 3;
    is ref $foo->{foo}, '';
    is $foo->{foo}, 'b';
    is $foo->{bar}, 'baz';

    $foo->{x} = 'y';
    isnt $hash->{x}, 'y';
}

{
    my $foo = $hash->as_hashref_mixed;
    is ref $foo, 'HASH';
    is scalar keys %$foo, 3;
    is ref $foo->{foo}, 'ARRAY';
    is_deeply $foo->{foo}, [ 'a', 'b' ];
    is $foo->{bar}, 'baz';
}

{
    my $foo = $hash->as_hashref_multi;
    is ref $foo, 'HASH';
    is scalar keys %$foo, 3;
    is ref $foo->{foo}, 'ARRAY';
    is_deeply $foo->{foo}, [ 'a', 'b' ];
    is_deeply $foo->{bar}, [ 'baz' ];
}

{
    my @output;
    $hash->each(sub { push @output, [ $_, @_ ] });
    is_deeply \@output,
        [
            [ 0, 'foo', 'a' ],
            [ 1, 'foo', 'b' ],
            [ 2, 'bar', 'baz' ],
            [ 3, 'baz', 33 ],
        ];
}

{
    # Test for this even though we want people not to do it
    $hash->each(sub { $_[1]++ });
    is_deeply [ $hash->flatten ],
        [ foo => 'b', foo => 'c', bar => 'bba', baz => 34 ];
    is_deeply $hash,
        { foo => 'b', bar => "baz", baz => 33 };

    is_deeply [ $hash->keys   ], [ qw(foo foo bar baz) ];
    is_deeply [ $hash->values ], [ qw(b c bba 34) ];
}

done_testing;
