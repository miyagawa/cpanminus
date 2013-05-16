use strict;
use Test::More;
use xt::Run;

# Miyagawa: these tests are vague: they only assert that the password 
# doesn't appear anywhere in the last_build_log.  They do not assert 
# *how* the password is actually masked, so you're free to change the
# implementation and the tests should still be somewhat useful.

my @test_cases = (
    [LWP  => [ qw(--no-curl --no-wget) ]],
    [curl => [ qw(--no-lwp  --no-wget) ]],
    [wget => [ qw(--no-lwp  --no-curl) ]],
);

for my $test_case (@test_cases) {

    my ($case_name, $backend_options) = @{ $test_case };

    subtest $case_name => sub {
        my $password = 's3cr3t';
        my $password_rx = qr/$password/;
        my $mirror_url = "http://username:$password\@cpan.perl.org";

        local $ENV{NODIAG} = 1; # So the output isn't dumped to screen
        my @cpanm_options = ("--verbose", "--mirror=$mirror_url", @{ $backend_options } );
        my ($out, $err, $exit) = run @cpanm_options, "Try::Tiny"; 

        unlike last_build_log, $password_rx, 'Password does not appear in the build log';
        unlike $out, $password_rx, 'Password does not appear on STDOUT';
        unlike $err, $password_rx, 'Password does not appear on STDIN';;
    };
}

done_testing;

