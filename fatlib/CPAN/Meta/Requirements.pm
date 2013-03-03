use strict;
use warnings;
package CPAN::Meta::Requirements;
our $VERSION = '2.122'; # VERSION
# ABSTRACT: a set of version requirements for a CPAN dist


use Carp ();
use Scalar::Util ();
use version 0.77 (); # the ->parse method


my @valid_options = qw( bad_version_hook );

sub new {
  my ($class, $options) = @_;
  $options ||= {};
  Carp::croak "Argument to $class\->new() must be a hash reference"
    unless ref $options eq 'HASH';
  my %self = map {; $_ => $options->{$_}} @valid_options;

  return bless \%self => $class;
}

sub _version_object {
  my ($self, $version) = @_;

  my $vobj;

  eval {
    $vobj  = (! defined $version)                ? version->parse(0)
           : (! Scalar::Util::blessed($version)) ? version->parse($version)
           :                                       $version;
  };

  if ( my $err = $@ ) {
    my $hook = $self->{bad_version_hook};
    $vobj = eval { $hook->($version) }
      if ref $hook eq 'CODE';
    unless (Scalar::Util::blessed($vobj) && $vobj->isa("version")) {
      $err =~ s{ at .* line \d+.*$}{};
      die "Can't convert '$version': $err";
    }
  }

  # ensure no leading '.'
  if ( $vobj =~ m{\A\.} ) {
    $vobj = version->parse("0$vobj");
  }

  # ensure normal v-string form
  if ( $vobj->is_qv ) {
    $vobj = version->parse($vobj->normal);
  }

  return $vobj;
}


BEGIN {
  for my $type (qw(minimum maximum exclusion exact_version)) {
    my $method = "with_$type";
    my $to_add = $type eq 'exact_version' ? $type : "add_$type";

    my $code = sub {
      my ($self, $name, $version) = @_;

      $version = $self->_version_object( $version );

      $self->__modify_entry_for($name, $method, $version);

      return $self;
    };
    
    no strict 'refs';
    *$to_add = $code;
  }
}


sub add_requirements {
  my ($self, $req) = @_;

  for my $module ($req->required_modules) {
    my $modifiers = $req->__entry_for($module)->as_modifiers;
    for my $modifier (@$modifiers) {
      my ($method, @args) = @$modifier;
      $self->$method($module => @args);
    };
  }

  return $self;
}


sub accepts_module {
  my ($self, $module, $version) = @_;

  $version = $self->_version_object( $version );

  return 1 unless my $range = $self->__entry_for($module);
  return $range->_accepts($version);
}


sub clear_requirement {
  my ($self, $module) = @_;

  return $self unless $self->__entry_for($module);

  Carp::confess("can't clear requirements on finalized requirements")
    if $self->is_finalized;

  delete $self->{requirements}{ $module };

  return $self;
}


sub requirements_for_module {
  my ($self, $module) = @_;
  my $entry = $self->__entry_for($module);
  return unless $entry;
  return $entry->as_string;
}


sub required_modules { keys %{ $_[0]{requirements} } }


sub clone {
  my ($self) = @_;
  my $new = (ref $self)->new;

  return $new->add_requirements($self);
}

sub __entry_for     { $_[0]{requirements}{ $_[1] } }

sub __modify_entry_for {
  my ($self, $name, $method, $version) = @_;

  my $fin = $self->is_finalized;
  my $old = $self->__entry_for($name);

  Carp::confess("can't add new requirements to finalized requirements")
    if $fin and not $old;

  my $new = ($old || 'CPAN::Meta::Requirements::_Range::Range')
          ->$method($version);

  Carp::confess("can't modify finalized requirements")
    if $fin and $old->as_string ne $new->as_string;

  $self->{requirements}{ $name } = $new;
}


sub is_simple {
  my ($self) = @_;
  for my $module ($self->required_modules) {
    # XXX: This is a complete hack, but also entirely correct.
    return if $self->__entry_for($module)->as_string =~ /\s/;
  }

  return 1;
}


sub is_finalized { $_[0]{finalized} }


sub finalize { $_[0]{finalized} = 1 }


sub as_string_hash {
  my ($self) = @_;

  my %hash = map {; $_ => $self->{requirements}{$_}->as_string }
             $self->required_modules;

  return \%hash;
}


my %methods_for_op = (
  '==' => [ qw(exact_version) ],
  '!=' => [ qw(add_exclusion) ],
  '>=' => [ qw(add_minimum)   ],
  '<=' => [ qw(add_maximum)   ],
  '>'  => [ qw(add_minimum add_exclusion) ],
  '<'  => [ qw(add_maximum add_exclusion) ],
);

sub add_string_requirement {
  my ($self, $module, $req) = @_;

  Carp::confess("No requirement string provided for $module")
    unless defined $req && length $req;

  my @parts = split qr{\s*,\s*}, $req;


  for my $part (@parts) {
    my ($op, $ver) = $part =~ m{\A\s*(==|>=|>|<=|<|!=)\s*(.*)\z};

    if (! defined $op) {
      $self->add_minimum($module => $part);
    } else {
      Carp::confess("illegal requirement string: $req")
        unless my $methods = $methods_for_op{ $op };

      $self->$_($module => $ver) for @$methods;
    }
  }
}


sub from_string_hash {
  my ($class, $hash) = @_;

  my $self = $class->new;

  for my $module (keys %$hash) {
    my $req = $hash->{$module};
    unless ( defined $req && length $req ) {
      $req = 0;
      Carp::carp("Undefined requirement for $module treated as '0'");
    }
    $self->add_string_requirement($module, $req);
  }

  return $self;
}

##############################################################

{
  package
    CPAN::Meta::Requirements::_Range::Exact;
  sub _new     { bless { version => $_[1] } => $_[0] }

  sub _accepts { return $_[0]{version} == $_[1] }

  sub as_string { return "== $_[0]{version}" }

  sub as_modifiers { return [ [ exact_version => $_[0]{version} ] ] }

  sub _clone {
    (ref $_[0])->_new( version->new( $_[0]{version} ) )
  }

  sub with_exact_version {
    my ($self, $version) = @_;

    return $self->_clone if $self->_accepts($version);

    Carp::confess("illegal requirements: unequal exact version specified");
  }

  sub with_minimum {
    my ($self, $minimum) = @_;
    return $self->_clone if $self->{version} >= $minimum;
    Carp::confess("illegal requirements: minimum above exact specification");
  }

  sub with_maximum {
    my ($self, $maximum) = @_;
    return $self->_clone if $self->{version} <= $maximum;
    Carp::confess("illegal requirements: maximum below exact specification");
  }

  sub with_exclusion {
    my ($self, $exclusion) = @_;
    return $self->_clone unless $exclusion == $self->{version};
    Carp::confess("illegal requirements: excluded exact specification");
  }
}

##############################################################

{
  package
    CPAN::Meta::Requirements::_Range::Range;

  sub _self { ref($_[0]) ? $_[0] : (bless { } => $_[0]) }

  sub _clone {
    return (bless { } => $_[0]) unless ref $_[0];

    my ($s) = @_;
    my %guts = (
      (exists $s->{minimum} ? (minimum => version->new($s->{minimum})) : ()),
      (exists $s->{maximum} ? (maximum => version->new($s->{maximum})) : ()),

      (exists $s->{exclusions}
        ? (exclusions => [ map { version->new($_) } @{ $s->{exclusions} } ])
        : ()),
    );

    bless \%guts => ref($s);
  }

  sub as_modifiers {
    my ($self) = @_;
    my @mods;
    push @mods, [ add_minimum => $self->{minimum} ] if exists $self->{minimum};
    push @mods, [ add_maximum => $self->{maximum} ] if exists $self->{maximum};
    push @mods, map {; [ add_exclusion => $_ ] } @{$self->{exclusions} || []};
    return \@mods;
  }

  sub as_string {
    my ($self) = @_;

    return 0 if ! keys %$self;

    return "$self->{minimum}" if (keys %$self) == 1 and exists $self->{minimum};

    my @exclusions = @{ $self->{exclusions} || [] };

    my @parts;

    for my $pair (
      [ qw( >= > minimum ) ],
      [ qw( <= < maximum ) ],
    ) {
      my ($op, $e_op, $k) = @$pair;
      if (exists $self->{$k}) {
        my @new_exclusions = grep { $_ != $self->{ $k } } @exclusions;
        if (@new_exclusions == @exclusions) {
          push @parts, "$op $self->{ $k }";
        } else {
          push @parts, "$e_op $self->{ $k }";
          @exclusions = @new_exclusions;
        }
      }
    }

    push @parts, map {; "!= $_" } @exclusions;

    return join q{, }, @parts;
  }

  sub with_exact_version {
    my ($self, $version) = @_;
    $self = $self->_clone;

    Carp::confess("illegal requirements: exact specification outside of range")
      unless $self->_accepts($version);

    return CPAN::Meta::Requirements::_Range::Exact->_new($version);
  }

  sub _simplify {
    my ($self) = @_;

    if (defined $self->{minimum} and defined $self->{maximum}) {
      if ($self->{minimum} == $self->{maximum}) {
        Carp::confess("illegal requirements: excluded all values")
          if grep { $_ == $self->{minimum} } @{ $self->{exclusions} || [] };

        return CPAN::Meta::Requirements::_Range::Exact->_new($self->{minimum})
      }

      Carp::confess("illegal requirements: minimum exceeds maximum")
        if $self->{minimum} > $self->{maximum};
    }

    # eliminate irrelevant exclusions
    if ($self->{exclusions}) {
      my %seen;
      @{ $self->{exclusions} } = grep {
        (! defined $self->{minimum} or $_ >= $self->{minimum})
        and
        (! defined $self->{maximum} or $_ <= $self->{maximum})
        and
        ! $seen{$_}++
      } @{ $self->{exclusions} };
    }

    return $self;
  }

  sub with_minimum {
    my ($self, $minimum) = @_;
    $self = $self->_clone;

    if (defined (my $old_min = $self->{minimum})) {
      $self->{minimum} = (sort { $b cmp $a } ($minimum, $old_min))[0];
    } else {
      $self->{minimum} = $minimum;
    }

    return $self->_simplify;
  }

  sub with_maximum {
    my ($self, $maximum) = @_;
    $self = $self->_clone;

    if (defined (my $old_max = $self->{maximum})) {
      $self->{maximum} = (sort { $a cmp $b } ($maximum, $old_max))[0];
    } else {
      $self->{maximum} = $maximum;
    }

    return $self->_simplify;
  }

  sub with_exclusion {
    my ($self, $exclusion) = @_;
    $self = $self->_clone;

    push @{ $self->{exclusions} ||= [] }, $exclusion;

    return $self->_simplify;
  }

  sub _accepts {
    my ($self, $version) = @_;

    return if defined $self->{minimum} and $version < $self->{minimum};
    return if defined $self->{maximum} and $version > $self->{maximum};
    return if defined $self->{exclusions}
          and grep { $version == $_ } @{ $self->{exclusions} };

    return 1;
  }
}

1;
# vim: ts=2 sts=2 sw=2 et:

__END__
=pod

