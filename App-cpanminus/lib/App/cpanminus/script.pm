package App::cpanminus::script;
use strict;
use base qw(Menlo::CLI::Compat);

sub doit {
    my $self = shift;
    return $self->run;
}

1;
