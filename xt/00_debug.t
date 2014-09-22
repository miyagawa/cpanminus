use CPAN::Meta;
use Test::More;
use Data::Dumper;
use Module::Metadata;
use xt::Run;

$Data::Dumper::Indent = 1;

sub debug_meta {
    my $metadata = Module::Metadata->new_from_module("CPAN::Meta");
    diag Dumper($metadata);
}

diag "$CPAN::Meta::VERSION from $INC{'CPAN/Meta.pm'}";
debug_meta;

run 'Test::Pod';
diag last_build_log;
debug_meta;

run 'CPAN::Meta';
diag last_build_log;
debug_meta;

ok 1;

done_testing;



