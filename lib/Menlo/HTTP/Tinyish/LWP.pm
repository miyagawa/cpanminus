package Menlo::HTTP::Tinyish::LWP;
use strict;
use LWP 5.802;
use LWP::UserAgent;

my %supports = (http => 1);

sub configure {
    if (eval { require LWP::Protocol::https; 1 }) {
        $supports{https} = 1;
    }
}

sub supports {
    $supports{$_[1]};
}

sub new {
    my($class, %attr) = @_;

    bless {
        ua => LWP::UserAgent->new($class->lwp_params(%attr)),
    }, $class;
}

sub _headers_to_hashref {
    my($self, $hdrs) = @_;

    my %headers;
    for my $field ($hdrs->header_field_names) {
        $headers{lc $field} = $hdrs->header($field); # could be an array ref
    }

    \%headers;
}

sub get {
    my($self, $url) = @_;
    my $res = $self->{ua}->request(HTTP::Request->new(GET => $url));
    return {
        url     => $url,
        content => $res->decoded_content,
        success => $res->is_success,
        status  => $res->code,
        reason  => $res->message,
        headers => $self->_headers_to_hashref($res->headers),
    };
}

sub mirror {
    my($self, $url, $file) = @_;
    my $res = $self->{ua}->mirror($url, $file);
    return {
        url     => $url,
        content => $res->decoded_content,
        success => $res->is_success,
        status  => $res->code,
        reason  => $res->message,
        headers => $self->_headers_to_hashref($res->headers),
    };
}

sub lwp_params {
    my($class, %attr) = @_;

    my %p = (
        parse_head => 0,
        env_proxy => 1,
        timeout => 30,
    );
    $p{agent} = delete $attr{agent};
    %p;
}

1;
