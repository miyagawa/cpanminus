use strict;
use Test::More;
use App::cpanminus::script;

use File::Temp;
$ENV{PERL_CPANM_HOME} = File::Temp::tempdir;

{
    my $app = App::cpanminus::script->new(mirrors => [ '/tmp' ]);
    $app->init;
    my $uris = $app->locate_dist("App::cpanoutdated");
    like $uris->[0]->(), qr/TOKUHIROM/;
}

done_testing;


