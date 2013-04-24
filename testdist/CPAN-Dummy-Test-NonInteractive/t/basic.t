use strict;
use Test::More;
use CPAN::Dummy::Test::NonInteractive;

if ($ENV{NONINTERACTIVE_TESTING}) {
    ok 1;
} else {
    alarm 5;
    my $in = <>;
    ok 1;
}

done_testing;
