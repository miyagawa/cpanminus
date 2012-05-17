package Module::CPANfile;
use strict;
use warnings;
use Cwd;

our $VERSION = '0.9007';

sub new {
    my($class, $file) = @_;
    bless {}, $class;
}

sub load {
    my($proto, $file) = @_;
    my $self = ref $proto ? $proto : $proto->new;
    $self->{file} = $file || "cpanfile";
    $self->parse;
    $self;
}

sub parse {
    my $self = shift;

    my $file = Cwd::abs_path($self->{file});
    $self->{result} = Module::CPANfile::Environment::parse($file) or die $@;
}

sub prereqs { shift->prereq }

sub prereq {
    my $self = shift;
    require CPAN::Meta::Prereqs;
    CPAN::Meta::Prereqs->new($self->prereq_specs);
}

sub prereq_specs {
    my $self = shift;
    $self->{result}{spec};
}

package Module::CPANfile::Environment;
use strict;

my @bindings = qw(
    on requires recommends suggests conflicts
    osname perl
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

$code;

\$_result;
EVAL
        $err = $@;
    }

    if ($err) { die "Parsing $file failed: $err" };

    return $res;
}

package Module::CPANfile::Result;
use strict;

sub new {
    bless {
        phase => 'runtime', # default phase
        spec  => {},
    }, shift;
}

sub on {
    my($self, $phase, $code) = @_;
    local $self->{phase} = $phase;
    $code->()
}

sub osname { die "TODO" }
sub perl { die "TODO" }

sub requires {
    my($self, $module, $requirement) = @_;
    $self->{spec}{$self->{phase}}{requires}{$module} = $requirement || 0;
}

sub recommends {
    my($self, $module, $requirement) = @_;
    $self->{spec}->{$self->{phase}}{recommends}{$module} = $requirement || 0;
}

sub suggests {
    my($self, $module, $requirement) = @_;
    $self->{spec}->{$self->{phase}}{suggests}{$module} = $requirement || 0;
}

sub conflicts {
    my($self, $module, $requirement) = @_;
    $self->{spec}->{$self->{phase}}{conflicts}{$module} = $requirement || 0;
}

# Module::Install compatible shortcuts

sub configure_requires {
    my($self, @args) = @_;
    $self->on(configure => sub { $self->requires(@args) });
}

sub build_requires {
    my($self, @args) = @_;
    $self->on(build => sub { $self->requires(@args) });
}

sub test_requires {
    my($self, @args) = @_;
    $self->on(test => sub { $self->requires(@args) });
}

sub author_requires {
    my($self, @args) = @_;
    $self->on(develop => sub { $self->requires(@args) });
}

package Module::CPANfile;

1;

__END__

=head1 NAME

Module::CPANfile - Parse cpanfile

=head1 SYNOPSIS

  use Module::CPANfile;

  my $file = Module::CPANfile->load("cpanfile");
  my $prereqs = $file->prereqs; # CPAN::Meta::Prereqs object

=head1 DESCRIPTION

Module::CPANfile is a tool to handle L<cpanfile> format to load application
specific dependencies, not just for CPAN distributions.

=head1 AUTHOR

Tatsuhiko Miyagawa

=head1 SEE ALSO

L<cpanfile>, L<CPAN::Meta>, L<CPAN::Meta::Spec>

=cut


