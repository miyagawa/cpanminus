use 5.006;
use strict;
use warnings;
package CPAN::Meta::Feature;
BEGIN {
  $CPAN::Meta::Feature::VERSION = '2.110930';
}
# ABSTRACT: an optional feature provided by a CPAN distribution

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




__END__



