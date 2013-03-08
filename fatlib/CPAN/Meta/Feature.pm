use 5.006;
use strict;
use warnings;
package CPAN::Meta::Feature;
our $VERSION = '2.120921'; # VERSION

use CPAN::Meta::Prereqs;


sub new {
  my ($class, $identifier, $spec) = @_;

  my %guts = (
    identifier  => $identifier,
    description => $spec->{description},
    prereqs     => CPAN::Meta::Prereqs->new($spec->{prereqs}),
  );

  bless \%guts => $class;
}


sub identifier  { $_[0]{identifier}  }


sub description { $_[0]{description} }


sub prereqs     { $_[0]{prereqs} }

1;

# ABSTRACT: an optional feature provided by a CPAN distribution




__END__



