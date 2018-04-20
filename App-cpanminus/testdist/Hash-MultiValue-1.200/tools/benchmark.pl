#!/usr/bin/perl
use strict;
use Benchmark;
use Hash::MultiValue;

package main;

my $how_many = shift || 100;

my @form = map { $_ => $_ % 5 == 0 ? [ rand 1000, rand 10000 ] :  rand 1000 } 1..$how_many;

timethese 0, {
    'normal hash' => sub {
        my %form = @form;
        my $form = \%form;
        my @k = keys %$form;
        $form->{14} = 1000;
        delete $form->{14};
        my @values = @{$form}{1..10};
    },
    multivalue => sub {
        my $form = Hash::MultiValue->new(@form);
        my @k = keys %$form;
        $form->{14} = 1000;
        delete $form->{14};
        my @values = @{$form}{1..10};
    },
    multivalue_oo => sub {
        my $form = Hash::MultiValue->new(@form);
        my @k = $form->keys;
        $form->add(14 => 1000);
        $form->remove(14);
        my @values = map $form->get($_), 1..10;
    },
};
