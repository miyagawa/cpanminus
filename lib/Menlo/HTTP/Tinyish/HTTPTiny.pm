package Menlo::HTTP::Tinyish::HTTPTiny;
use strict;
use HTTP::Tiny;

my %supports = (http => 1);

sub configure {
    my %meta = ("HTTP::Tiny" => $HTTP::Tiny::VERSION);

    if (eval { HTTP::Tiny::Handle->_assert_ssl; 1 }) {
        $supports{https} = 1;
    }

    \%meta;
}

sub supports { $supports{$_[1]} }

sub new {
    my($class, %attrs) = @_;
    bless {
        tiny => HTTP::Tiny->new(%attrs),
    }, $class;
}

sub get {
    my($self, $url) = @_;
    $self->{tiny}->get($url);
}

sub mirror {
    my($self, $url, $file) = @_;
    $self->{tiny}->mirror($url, $file);
}

1;

