package Module::CPANfile::Prereq;
use strict;

sub new {
    my($class, %options) = @_;
    bless \%options, $class;
}

sub feature { $_[0]->{feature} }
sub phase   { $_[0]->{phase} }
sub type    { $_[0]->{type} }
sub module  { $_[0]->{module} }
sub requirement { $_[0]->{requirement} }

sub match_feature {
    my($self, $identifier) = @_;
    no warnings 'uninitialized';
    $self->feature eq $identifier;
}

1;
