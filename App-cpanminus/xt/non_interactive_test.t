use strict;
use xt::Run;
use Test::More;

run '--test-only', './testdist/CPAN-Dummy-Test-NonInteractive';
like last_build_log, qr/Result: PASS/;

done_testing;
