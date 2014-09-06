use strict;
use Test::More;
use JSON;
use Config;
use xt::Run;

my $local_lib = "$ENV{PERL_CPANM_HOME}/perl5";

sub install_json {
    my($path, $dist) = @_;

    run_L '--notest', $path;

    my $file = "$local_lib/lib/perl5/$Config{archname}/.meta/$dist/install.json";
    open my $in, "<", $file or die $!;
    JSON::decode_json(join "", <$in>);
}


{
    my $data = install_json('DSKOLL/IO-stringy-2.110.tar.gz', 'IO-stringy-2.110');
    is $data->{name}, "IO::Stringy";
    is $data->{version}, '2.110';

    # pmfiles in t/ should be excluded
    ok !$data->{provides}{"Common"};
    ok !$data->{provides}{"ExtUtils::TBone"};
}

{
    my $data = install_json('Test::TCP@2.00', 'Test-TCP-2.00');
    ok !$data->{provides}{MyBuilder};
}

done_testing;
