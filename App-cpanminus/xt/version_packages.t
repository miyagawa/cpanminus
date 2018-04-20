use strict;
use Test::More;
use xt::Run;

run "XML::SAX";
run "XML::SAX::ParserFactory";

like last_build_log, qr/Successfully reinstalled/;

done_testing;


