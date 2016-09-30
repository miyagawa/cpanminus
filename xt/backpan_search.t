use strict;
use xt::Run;
use Test::More;

{
    run 'Net::LDAP::Server::Test@0.14';
    like last_build_log, qr/Fetching .*backpan/;
}

{
    # --dev shouldn't search for backpan
    run '--info', '--dev', 'Test::More';
    unlike last_build_log, qr/backpan/;
}

{
    my $out = run '--info', 'Moose::Util::TypeConstraints~<=2.0402';
    like $out, qr/Moose-2.0402/;
}

done_testing;

