package Menlo::Util;
use strict;

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(WIN32 safe_string safe_system safe_capture);

use constant WIN32 => $^O eq 'MSWin32';

if (WIN32) {
    require Win32::ShellQuote;
    *shell_quote = \&Win32::ShellQuote::quote_native;
} else {
    require String::ShellQuote;
    *shell_quote = \&String::ShellQuote::shell_quote_best_effort;
}

sub safe_string {
    join ' ', map { ref $_ ? shell_quote(@$_) : $_ } @_;
}

sub safe_system {
    my $cmd = safe_string(@_);
    system $cmd;
}

sub safe_capture {
    my $cmd = safe_string(@_);
    `$cmd`;
}

1;
