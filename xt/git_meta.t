use strict;
use Test::More;
use Config;
use JSON;
use xt::Run;

sub load_json {
    open my $in, "<", $_[0] or die "$_[0]: $!";
    JSON::decode_json(join "", <$in>);
}

my $local_lib = "$ENV{PERL_CPANM_HOME}/perl5";

{
    run_L "git://github.com/miyagawa/CPAN-Test-Dummy-FromGit.git";
    like last_build_log, qr/installed .*-0\.01/;

    my $file = "$local_lib/lib/perl5/$Config{archname}/.meta/CPAN-Test-Dummy-FromGit-6f45b52/install.json";
    my $data = load_json $file;
    is $data->{name}, 'CPAN::Test::Dummy::FromGit';
    is $data->{revision}, '6f45b52';
    is $data->{uri}, 'git://github.com/miyagawa/CPAN-Test-Dummy-FromGit.git';
}

{
    run_L 'git://github.com/miyagawa/CPAN-Test-Dummy-FromGit.git@devel';
    like last_build_log, qr/Cloning/;
    like last_build_log, qr/installed .*-0\.02/;

    my $file = "$local_lib/lib/perl5/$Config{archname}/.meta/CPAN-Test-Dummy-FromGit-acdffda/install.json";
    my $data = load_json $file;
    is $data->{name}, 'CPAN::Test::Dummy::FromGit';
    is $data->{revision}, 'acdffda';
    is $data->{uri}, 'git://github.com/miyagawa/CPAN-Test-Dummy-FromGit.git';
}

done_testing;

