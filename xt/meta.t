use strict;
use Test::More;
use JSON;
use Config;
use xt::Run;
use version;

sub load_json {
    open my $in, "<", $_[0] or die "$_[0]: $!";
    JSON::decode_json(join "", <$in>);
}

my $local_lib = "$ENV{PERL_CPANM_HOME}/perl5";

{
    # http://www.cpan.org/ no longer has 0.10, switch up to 0.15
    run_L "MIYAGAWA/Hash-MultiValue-0.15.tar.gz";

    my $dist = (last_build_log =~ /Configuring (Hash-\S+)/)[0];

    my $file = "$local_lib/lib/perl5/$Config{archname}/.meta/$dist/install.json";

    my $data = load_json $file;
    is $data->{name}, "Hash::MultiValue";
    is_deeply $data->{provides}{"Hash::MultiValue"}, { file => "lib/Hash/MultiValue.pm", version => "0.15" };
}

{
    run_L "http://backpan.perl.org/authors/id/M/ML/MLEHMANN/common-sense-3.73.tar.gz";
    my $file = "$local_lib/lib/perl5/$Config{archname}/.meta/common-sense-3.73/install.json";

    my $data = load_json $file;
    is $data->{name}, "common::sense";
    is_deeply $data->{provides}{"common::sense"}, { file => "sense.pm.PL", version => "3.73" };
}

{
    run_L 'Module::CPANfile@0.9035';
    my $file = "$local_lib/lib/perl5/$Config{archname}/.meta/Module-CPANfile-0.9035/install.json";
    my $data = load_json $file;
    ok exists $data->{provides}{"Module::CPANfile"};
    ok !exists $data->{provides}{"xt::Utils"};
}

my @modules = (
    'Algorithm::Diff', '1.1902',
    'Test::Object', '0.07',
    'IO::String', '1.08',
    'Class::Accessor::Chained', '0.01',
    'Readonly', '1.03',
    'CPAN::Test::Dummy::Perl5::VersionDeclare', 'v0.0.1',
    'CPAN::Test::Dummy::Perl5::VersionQV', 'v0.1.0',
    'Scrabble::Dict', '0.01',
);

while (@modules) {
    my($module, $version) = splice @modules, 0, 2;
    (my $dist = $module) =~ s/::/-/g;
    run_L "$module\@$version";
    my $file = "$local_lib/lib/perl5/$Config{archname}/.meta/$dist-$version/install.json";
    my $data = load_json $file;
    ok exists $data->{provides}{$module};
    my $want_ver = $version =~ /^v/ ? version->new($version)->numify : $version;
    is $data->{provides}{$module}{version}, $want_ver, "$module $want_ver";
}

done_testing;
