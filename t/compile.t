#!perl

use strict;
use Test::More tests => 2;

BEGIN {
    require_ok 'Menlo';
    require_ok 'Menlo::CLI::Compat';
}

diag("Menlo/$Menlo::VERSION");

__DATA__
