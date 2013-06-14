package Module::CPANfile::Environment;
use strict;
use Module::CPANfile::Result;
use Carp ();

my @bindings = qw(
    on requires recommends suggests conflicts
    feature
    osname
    configure_requires build_requires test_requires author_requires
);

my $file_id = 1;

sub import {
    my($class, $result_ref) = @_;
    my $pkg = caller;

    $$result_ref = Module::CPANfile::Result->new;
    for my $binding (@bindings) {
        no strict 'refs';
        *{"$pkg\::$binding"} = sub { $$result_ref->$binding(@_) };
    }
}

sub parse {
    my $file = shift;

    my $code = do {
        open my $fh, "<", $file or die "$file: $!";
        join '', <$fh>;
    };

    my($res, $err);

    {
        local $@;
        $res = eval sprintf <<EVAL, $file_id++;
package Module::CPANfile::Sandbox%d;
no warnings;
my \$_result;
BEGIN { import Module::CPANfile::Environment \\\$_result };

# line 1 "$file"
$code;

\$_result;
EVAL
        $err = $@;
    }

    if ($err) { die "Parsing $file failed: $err" };

    return $res;
}

1;

