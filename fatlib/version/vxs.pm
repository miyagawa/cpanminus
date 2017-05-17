#!perl -w
package version::vxs;

use v5.10;
use strict;

use vars qw(@ISA $VERSION $CLASS );
$VERSION = 0.9918;
$CLASS = 'version::vxs';

eval {
    require XSLoader;
    local $^W; # shut up the 'redefined' warning for UNIVERSAL::VERSION
    XSLoader::load('version::vxs', $VERSION);
    1;
} or do {
    require DynaLoader;
    push @ISA, 'DynaLoader'; 
    local $^W; # shut up the 'redefined' warning for UNIVERSAL::VERSION
    bootstrap version::vxs $VERSION;
};

# Preloaded methods go here.

1;
