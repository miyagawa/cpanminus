package Module::CPANfile::Result;
use strict;

sub from_prereqs {
    my($class, $spec) = @_;
    bless {
        phase => 'runtime',
        spec => $spec,
    }, $class;
}

sub new {
    bless {
        phase => 'runtime', # default phase
        features => {},
        feature => undef,
        spec  => {},
    }, shift;
}

sub on {
    my($self, $phase, $code) = @_;
    local $self->{phase} = $phase;
    $code->()
}

sub feature {
    my($self, $identifier, $description, $code) = @_;

    # shortcut: feature identifier => sub { ... }
    if (@_ == 3 && ref($description) eq 'CODE') {
        $code = $description;
        $description = $identifier;
    }

    unless (ref $description eq '' && ref $code eq 'CODE') {
        Carp::croak("Usage: feature 'identifier', 'Description' => sub { ... }");
    }

    local $self->{feature} = $self->{features}{$identifier}
      = { identifier => $identifier, description => $description, spec => {} };
    $code->();
}

sub osname { die "TODO" }

sub requires {
    my($self, $module, $requirement) = @_;
    ($self->{feature} ? $self->{feature}{spec} : $self->{spec})
      ->{$self->{phase}}{requires}{$module} = $requirement || 0;
}

sub recommends {
    my($self, $module, $requirement) = @_;
    ($self->{feature} ? $self->{feature}{spec} : $self->{spec})
      ->{$self->{phase}}{recommends}{$module} = $requirement || 0;
}

sub suggests {
    my($self, $module, $requirement) = @_;
    ($self->{feature} ? $self->{feature}{spec} : $self->{spec})
      ->{$self->{phase}}{suggests}{$module} = $requirement || 0;
}

sub conflicts {
    my($self, $module, $requirement) = @_;
    ($self->{feature} ? $self->{feature}{spec} : $self->{spec})
      ->{$self->{phase}}{conflicts}{$module} = $requirement || 0;
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

1;
