package HelloWorld;
use 5.008001;
our $VERSION = '0.01';

require XSLoader;
XSLoader::load('HelloWorld', $VERSION);

1;

