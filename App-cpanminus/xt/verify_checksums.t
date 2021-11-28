use strict;
use lib ".";
use xt::Run;
use Test::More;

use File::Temp ();
use File::Which ();
use HTTP::Tinyish;

my $gpg = File::Which::which "gpg";

plan skip_all => 'need gpg' if !$gpg;

{
    # XXX As of 2021-11-29, Module::Signature does not bundle PAUSE2022.pub,
    # so we should import PAUSE2022 by ourselves
    my $url = "https://raw.githubusercontent.com/andk/cpanpm/master/PAUSE2022.pub";
    my $res = HTTP::Tinyish->new->get($url);
    die "$res->{status} $res->{reason}, $url\n" if !$res->{success};
    my $tempfile = File::Temp->new;
    $tempfile->print($res->{content});
    $tempfile->close;
    !system $gpg, "--quiet", "--import", $tempfile->filename or die;
}

run "--reinstall", "--verify", "URI";
like last_build_log, qr/Fetching.*CHECKSUMS/;
like last_build_log, qr/Checksum.*Verified/;

done_testing;
