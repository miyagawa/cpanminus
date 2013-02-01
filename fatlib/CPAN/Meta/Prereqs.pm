use 5.006;
use strict;
use warnings;
package CPAN::Meta::Prereqs;
our $VERSION = '2.120921'; # VERSION


use Carp qw(confess);
use Scalar::Util qw(blessed);
use CPAN::Meta::Requirements 2.121;


sub __legal_phases { qw(configure build test runtime develop)   }
sub __legal_types  { qw(requires recommends suggests conflicts) }

# expect a prereq spec from META.json -- rjbs, 2010-04-11
sub new {
  my ($class, $prereq_spec) = @_;
  $prereq_spec ||= {};

  my %is_legal_phase = map {; $_ => 1 } $class->__legal_phases;
  my %is_legal_type  = map {; $_ => 1 } $class->__legal_types;

  my %guts;
  PHASE: for my $phase (keys %$prereq_spec) {
    next PHASE unless $phase =~ /\Ax_/i or $is_legal_phase{$phase};

    my $phase_spec = $prereq_spec->{ $phase };
    next PHASE unless keys %$phase_spec;

    TYPE: for my $type (keys %$phase_spec) {
      next TYPE unless $type =~ /\Ax_/i or $is_legal_type{$type};

      my $spec = $phase_spec->{ $type };

      next TYPE unless keys %$spec;

      $guts{prereqs}{$phase}{$type} = CPAN::Meta::Requirements->from_string_hash(
        $spec
      );
    }
  }

  return bless \%guts => $class;
}


sub requirements_for {
  my ($self, $phase, $type) = @_;

  confess "requirements_for called without phase" unless defined $phase;
  confess "requirements_for called without type"  unless defined $type;

  unless ($phase =~ /\Ax_/i or grep { $phase eq $_ } $self->__legal_phases) {
    confess "requested requirements for unknown phase: $phase";
  }

  unless ($type =~ /\Ax_/i or grep { $type eq $_ } $self->__legal_types) {
    confess "requested requirements for unknown type: $type";
  }

  my $req = ($self->{prereqs}{$phase}{$type} ||= CPAN::Meta::Requirements->new);

  $req->finalize if $self->is_finalized;

  return $req;
}


sub with_merged_prereqs {
  my ($self, $other) = @_;

  my @other = blessed($other) ? $other : @$other;

  my @prereq_objs = ($self, @other);

  my %new_arg;

  for my $phase ($self->__legal_phases) {
    for my $type ($self->__legal_types) {
      my $req = CPAN::Meta::Requirements->new;

      for my $prereq (@prereq_objs) {
        my $this_req = $prereq->requirements_for($phase, $type);
        next unless $this_req->required_modules;

        $req->add_requirements($this_req);
      }

      next unless $req->required_modules;

      $new_arg{ $phase }{ $type } = $req->as_string_hash;
    }
  }

  return (ref $self)->new(\%new_arg);
}


sub as_string_hash {
  my ($self) = @_;

  my %hash;

  for my $phase ($self->__legal_phases) {
    for my $type ($self->__legal_types) {
      my $req = $self->requirements_for($phase, $type);
      next unless $req->required_modules;

      $hash{ $phase }{ $type } = $req->as_string_hash;
    }
  }

  return \%hash;
}


sub is_finalized { $_[0]{finalized} }


sub finalize {
  my ($self) = @_;

  $self->{finalized} = 1;

  for my $phase (keys %{ $self->{prereqs} }) {
    $_->finalize for values %{ $self->{prereqs}{$phase} };
  }
}


sub clone {
  my ($self) = @_;

  my $clone = (ref $self)->new( $self->as_string_hash );
}

1;

# ABSTRACT: a set of distribution prerequisites by phase and type




__END__



