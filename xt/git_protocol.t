use strict;
use Test::More;
use xt::Run;

plan skip_all => "Don't run without a checkout" unless -e '.git';

my @urls = (
    [ 'git+ssh://git@github.com/miyagawa/CPAN-Test-Dummy-FromGit.git', '0.01' ],
    [ 'git+ssh://git@github.com/miyagawa/CPAN-Test-Dummy-FromGit.git@devel', '0.02' ],
    [ 'ssh://git@github.com/miyagawa/CPAN-Test-Dummy-FromGit.git', '0.01' ],
    [ 'ssh://git@github.com/miyagawa/CPAN-Test-Dummy-FromGit.git@devel', '0.02' ],
    [ 'https://github.com/miyagawa/CPAN-Test-Dummy-FromGit.git', '0.01' ],
    [ 'https://github.com/miyagawa/CPAN-Test-Dummy-FromGit.git@devel', '0.02' ],
    [ 'git+https://github.com/miyagawa/CPAN-Test-Dummy-FromGit.git', '0.01' ],
    [ 'git+https://github.com/miyagawa/CPAN-Test-Dummy-FromGit.git@devel', '0.02' ],
    [ 'git@github.com:miyagawa/CPAN-Test-Dummy-FromGit.git', '0.01' ],
    [ 'git@github.com:miyagawa/CPAN-Test-Dummy-FromGit.git@devel', '0.02' ],
);

for my $repo (@urls) {
    my($url, $ver) = @$repo;
    run $url;
    like last_build_log, qr/Cloning/, "cloned $url";
    like last_build_log, qr/installed .*-\Q$ver\E/, "$url - $ver";
}

done_testing;

