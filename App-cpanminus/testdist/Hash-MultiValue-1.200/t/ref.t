use Test::More;
BEGIN {
    eval { require UNIVERSAL::ref };
    plan skip_all => 'No UNIVERSAL::ref' if $@;
}

use Hash::MultiValue;

my $h = Hash::MultiValue->new;
is ref $h, 'HASH';

done_testing;

