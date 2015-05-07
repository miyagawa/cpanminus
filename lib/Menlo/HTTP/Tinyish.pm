package Menlo::HTTP::Tinyish;
use strict;
use warnings;
use Carp ();

our $PreferredBackend; # for tests
our @Backends = map "Menlo::HTTP::Tinyish::$_", qw( LWP HTTPTiny Curl Wget );
my %configured;

sub new {
    my($class, %attr) = @_;
    bless \%attr, $class;
}

sub get {
    my $self = shift;
    $self->_backend_for($_[0])->get(@_);
}

sub mirror {
    my $self = shift;
    $self->_backend_for($_[0])->mirror(@_);
}

sub _backend_for {
    my($self, $url) = @_;

    my($scheme) = $url =~ m!^(https?):!;
    Carp::croak "URL Scheme '$url' not supported." unless $scheme;

    for my $backend ($self->backends) {
        $self->configure_backend($backend) or next;
        if ($backend->supports($scheme)) {
            return $backend->new(%$self);
        }
    }

    Carp::croak "No backend configured for scheme $scheme";
}

sub backends {
    $PreferredBackend ? ($PreferredBackend) : @Backends;
}

sub configure_backend {
    my($self, $backend) = @_;
    unless (exists $configured{$backend}) {
        $configured{$backend} =
          eval { require_module($backend); $backend->configure; 1 };
    }
    $configured{$backend};
}

sub require_module {
    local $_ = shift;
    s!::!/!g;
    require "$_.pm";
}

1;

__END__

=head1 NAME

Menlo::HTTP::Tinyish - HTTP::Tiny compatible HTTP client wrappers

=head1 SYNOPSIS

  my $res = Menlo::HTTP::Tinyish->new->get("http://www.cpan.org/");

=head1 DESCRIPTION

Menlo::HTTP::Tinyish is a wrapper module for HTTP client modules
L<LWP>, L<HTTP::Tiny> and HTTP client software C<curl> and C<wget>.

It provides an API compatible to HTTP::Tiny, and the implementation
has been extracted out of L<App::cpanminus>. This module can be useful
in a restrictive environment where you need to be able to download
CPAN modules without an HTTPS support in built-in HTTP library.

=head1 SUPPORTED METHODS

C<get> and C<mirror> are only supported right now.

=head1 SIMILAR MODULES

=over 4

=item *

L<File::Fetch> - is core since 5.10. Has support for non-HTTP protocols such as ftp and git. Does not support HTTPS or basic authentication as of this writing.

=item *

L<Plient> - provides more complete runtime API, but is only compatible on Unix environments.

=item *

L<HTTP::Tiny::CLI> - only provides curl interface so far, and does not provide C<mirror> wrapper.

=back

=head1 AUTHOR

Tatsuhiko Miyagawa

=cut

