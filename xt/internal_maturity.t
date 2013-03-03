use strict;
use Test::More;
use App::cpanminus::script;

use constant NOT_BACKPAN => { not => { term => { status => 'backpan' } } };
use constant RELEASED    => { term => { maturity => 'released' } };

sub maturity {
    my($module, $version, $dev) = @_;

    my $s = App::cpanminus::script->new;
    $s->{dev_release} = $dev;
    [ $s->maturity_filter($module, $version) ];
}

my @tests = (
    [ 'Test::More' ] => [ NOT_BACKPAN, RELEASED ],
    [ 'Test::More', '==1.0' ] => [ ],
    [ 'Test::More', undef, 1 ] => [ NOT_BACKPAN ],
    [ 'Test::More', '< 2.0' ] => [ RELEASED ],
    [ 'Test::More', '< 2.0', 1 ] => [ NOT_BACKPAN ],
);

while (@tests) {
    my($t, $r) = splice @tests, 0, 2;
    is_deeply maturity(@$t), $r, $t->[0];
}

done_testing;
