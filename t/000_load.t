#!perl

use strict;
use Test::More tests => 1;

BEGIN{
    require_ok 'App::cpanminus';

    # in the future ...
    # require_ok 'App::cpanminus::script'; 
}

diag("App::cpanminus/$App::cpanminus::VERSION");

__DATA__
