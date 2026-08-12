use strict;
use lib 'lib';
use App::cpanminus::script;
use Test::More;

{
    package Local::cpanm;
    use parent -norequire, 'App::cpanminus::script';

    sub get {
        return <<'HISTORY';
Example::Module 1.00 A/AU/AUTHOR/Example-Module-1.00.tar.gz
Example::Module 2.00 A/AU/AUTHOR/Example-Module-2.00.tar.gz
HISTORY
    }

    sub cpan_module {
        my($self) = @_;
        push @{$self->{observed_mirrors}}, [ @{$self->{mirrors}} ];
        return 1;
    }
}

my $mirror = 'http://www.cpan.example';
my $cpanm = Local::cpanm->new(
    mirrors => [$mirror],
    observed_mirrors => [],
);

$cpanm->search_cpanmetadb_history('Example::Module', '== 1.00');
is_deeply(
    $cpanm->{observed_mirrors}->[-1],
    ['http://backpan.perl.org', $mirror],
    'historical lookup temporarily prepends BackPAN',
);
is_deeply(
    $cpanm->{mirrors},
    [$mirror],
    'historical lookup preserves the configured mirrors',
);

$cpanm->search_cpanmetadb_history('Example::Module', '== 2.00');
is_deeply(
    $cpanm->{observed_mirrors}->[-1],
    [$mirror],
    'latest release lookup does not prepend BackPAN',
);
is_deeply(
    $cpanm->{mirrors},
    [$mirror],
    'latest release lookup preserves the configured mirrors',
);

done_testing;
