package URI::rtspu;

use strict;
use warnings;

our $VERSION = '1.73';
$VERSION = eval $VERSION;

use parent 'URI::rtsp';

sub default_port { 554 }

1;
