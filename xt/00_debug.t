use CPAN::Meta;
use Test::More;
use Data::Dumper;
use Module::Metadata;
use xt::Run;

$Data::Dumper::Indent = 1;

diag "$CPAN::Meta::VERSION from $INC{'CPAN/Meta.pm'}";

{
    my $metadata = Module::Metadata->new_from_module("CPAN::Meta");
    diag Dumper($metadata);
}

run 'CPAN::Meta';
diag last_build_log;

{
    my $metadata = Module::Metadata->new_from_module("CPAN::Meta");
    diag Dumper($metadata);
}

ok 1;

done_testing;



