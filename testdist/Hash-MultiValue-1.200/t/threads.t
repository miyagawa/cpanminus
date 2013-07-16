use strict;
use Config;
use Test::More;
use Hash::MultiValue;

BEGIN {
    plan skip_all => "perl interpreter is not compiled with ithreads"
      unless $Config{useithreads};

    plan skip_all => "perl 5.8.1 required for thread tests"
      unless $] > '5.0080009';

    require threads;
}

plan tests => 2;

my $h = Hash::MultiValue->new(foo => 'bar');
my @exp = ('bar');

is_deeply([$h->get_all('foo')], \@exp, 'got expected results');

my @got = threads->create(sub { 
    $h->get_all('foo');
})->join;

is_deeply(\@got, \@exp, 'got expected results in cloned interpreter');

