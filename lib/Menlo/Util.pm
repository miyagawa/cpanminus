package Menlo::Util;
use strict;

use File::Which ();
use Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(WIN32);

use constant WIN32 => $^O eq 'MSWin32';

if (WIN32) {
    require Win32::ShellQuote;
    *shell_quote = \&Win32::ShellQuote::quote_native;
} else {
    require String::ShellQuote;
    *shell_quote = \&String::ShellQuote::shell_quote_best_effort;
}

sub which {
    my($name, $quote) = @_;
    my $path = File::Which::which($name);
    return unless $path;
    return $path unless $quote;
    $path =~ /\s/ ? shell_quote($path) : $path;
}

1;

