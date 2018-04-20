package Module::CPANfile::Prereqs;
use strict;
use Carp ();
use CPAN::Meta::Feature;
use Module::CPANfile::Prereq;

sub from_cpan_meta {
    my($class, $prereqs) = @_;

    my $self = $class->new;

    for my $phase (keys %$prereqs) {
        for my $type (keys %{ $prereqs->{$phase} }) {
            while (my($module, $requirement) = each %{ $prereqs->{$phase}{$type} }) {
                $self->add_prereq(
                    phase => $phase,
                    type  => $type,
                    module => $module,
                    requirement => Module::CPANfile::Requirement->new(name => $module, version => $requirement),
                );
            }
        }
    }

    $self;
}

sub new {
    my $class = shift;
    bless {
        prereqs => [],
        features => {},
    }, $class;
}

sub add_feature {
    my($self, $identifier, $description) = @_;
    $self->{features}{$identifier} = { description => $description };
}

sub add_prereq {
    my($self, %args) = @_;
    $self->add( Module::CPANfile::Prereq->new(%args) );
}

sub add {
    my($self, $prereq) = @_;
    push @{$self->{prereqs}}, $prereq;
}

sub as_cpan_meta {
    my $self = shift;
    $self->{cpanmeta} ||= $self->build_cpan_meta;
}

sub build_cpan_meta {
    my($self, $identifier) = @_;

    my $prereq_spec = {};
    $self->prereq_each($identifier, sub {
        my $prereq = shift;
        $prereq_spec->{$prereq->phase}{$prereq->type}{$prereq->module} = $prereq->requirement->version;
    });

    CPAN::Meta::Prereqs->new($prereq_spec);
}

sub prereq_each {
    my($self, $identifier, $code) = @_;

    for my $prereq (@{$self->{prereqs}}) {
        next unless $prereq->match_feature($identifier);
        $code->($prereq);
    }
}

sub merged_requirements {
    my $self = shift;

    my $reqs = CPAN::Meta::Requirements->new;
    for my $prereq (@{$self->{prereqs}}) {
        $reqs->add_string_requirement($prereq->module, $prereq->requirement->version);
    }

    $reqs;
}

sub find {
    my($self, $module) = @_;

    for my $prereq (@{$self->{prereqs}}) {
        return $prereq if $prereq->module eq $module;
    }

    return;
}

sub identifiers {
    my $self = shift;
    keys %{$self->{features}};
}

sub feature {
    my($self, $identifier) = @_;

    my $data = $self->{features}{$identifier}
      or Carp::croak("Unknown feature '$identifier'");

    my $prereqs = $self->build_cpan_meta($identifier);

    CPAN::Meta::Feature->new($identifier, {
        description => $data->{description},
        prereqs => $prereqs->as_string_hash,
    });
}

1;
