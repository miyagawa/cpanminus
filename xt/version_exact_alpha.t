use strict;
use Test::More;
use xt::Run;

{
    run 'Perl::Version~==v1.13.30';
    like last_build_log, qr/Successfully (?:re)?installed/, 'Normalized alpha version matched';
}

{
    run 'Perl::Version~==1.013_03';
    like last_build_log, qr/Successfully (?:re)?installed/, 'Underscored alpha version matched';
}

done_testing;
