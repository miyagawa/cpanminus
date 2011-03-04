use strict;
use Test::More;
use xt::Run;

run "XML::SAX";
run "XML::SAX::ParserFactory";

my $log = last_build_log;
like $log, qr/Successfully reinstalled/;

done_testing;


