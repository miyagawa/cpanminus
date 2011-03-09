package lib::core::only;

use strict;
use warnings FATAL => 'all';
use Config;

sub import {
  @INC = @Config{qw(privlibexp archlibexp)};
  return
}

1;
