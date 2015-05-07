package Menlo::HTTP::Tinyish::Curl;
use strict;
use warnings;
use IPC::Run3 qw(run3);
use File::Which qw(which);
use Menlo::HTTP::Tinyish::Util qw(parse_http_response internal_error);

my %supports;
my $curl;

sub configure {
    my $class = shift;

    $curl = which('curl');

    eval {
        run3(['curl-config', '--protocols'], \undef, \my @lines, \undef);
        for (@lines) {
            /^(HTTPS?)\s*$/ and $supports{lc $1} = 1;
        }
    };
}

sub supports { $supports{$_[1]} }

sub new {
    my($class, %attr) = @_;
    bless \%attr, $class;
}

sub get {
    my($self, $url) = @_;

    my($output, $error);
    eval {
        run3 [$curl, $self->build_options($url), $url], \undef, \$output, \$error;
    };

    if ($@ or $?) {
        return internal_error($url, $@ || $error);
    }

    my $res = { url => $url };
    parse_http_response($output, $res);
    $res;
}

sub mirror {
    my($self, $url, $file) = @_;

    my $output;
    eval {
        run3 [$curl, $self->build_options($url), $url, '-z', $file, '-o', $file, '--remote-time'], \undef, \$output, \undef;
    };

    if ($@) {
        return internal_error($url, $@);
    }

    my $res = { url => $url };
    parse_http_response($output, $res);
    $res;
}

sub build_options {
    my($self, $url) = @_;

    my @options = (
        '--location',
        '--silent',
        '--dump-header', '-',
    );

    if ($self->{agent}) {
        push @options,
          '--user-agent', $self->{agent};
    }

    @options;
}

1;
