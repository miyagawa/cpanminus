use strict;
use Test::More;
use JSON;
use Config;
use xt::Run;

sub load_json {
    open my $in, "<", $_[0] or die "$_[0]: $!";
    JSON::decode_json(join "", <$in>);
}

my $local_lib = "$ENV{PERL_CPANM_HOME}/perl5";

{
    run_L "CPAN::Test::Dummy::Perl5::DifferentProvides";
    my $file = "$local_lib/lib/perl5/$Config{archname}/.meta/CPAN-Test-Dummy-Perl5-DifferentProvides-0.01/install.json";

    my $data = load_json $file;
    is $data->{name}, "CPAN::Test::Dummy::Perl5::DifferentProvides";
    is_deeply $data->{provides}, {
        'CPAN::Test::Dummy::Perl5::DifferentProvides' => {
            file => "lib/CPAN/Test/Dummy/Perl5/DifferentProvides.pm",
            version => "0.01",
        },
        'CPAN::Test::Dummy::Perl5::DifferentProvides::B' => {
            file => "lib/CPAN/Test/Dummy/Perl5/DifferentProvides/B.pm",
            version => "0.01",
        },
    };
}

{
    run_L "SAPER/XSLoader-0.22.tar.gz";
    my $file = "$local_lib/lib/perl5/$Config{archname}/.meta/XSLoader-0.22/install.json";

    my $data = load_json $file;
    ok exists $data->{provides}{XSLoader};
}

done_testing;

