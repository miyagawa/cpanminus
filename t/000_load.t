#!perl

use strict;
use Test::More tests => 2;

BEGIN{
    require_ok 'App::cpanminus';
    require_ok 'App::cpanminus::script';
}

diag("App::cpanminus/$App::cpanminus::VERSION");

__DATA__
