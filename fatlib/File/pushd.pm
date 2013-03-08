use strict;
use warnings;
package File::pushd;
# ABSTRACT: change directory temporarily for a limited scope
our $VERSION = '1.004'; # VERSION

our @EXPORT  = qw( pushd tempd );
our @ISA     = qw( Exporter );

use Exporter;
use Carp;
use Cwd         qw( cwd abs_path );
use File::Path  qw( rmtree );
use File::Temp  qw();
use File::Spec;

use overload
    q{""} => sub { File::Spec->canonpath( $_[0]->{_pushd} ) },
    fallback => 1;

#--------------------------------------------------------------------------#
# pushd()
#--------------------------------------------------------------------------#

sub pushd {
    my ($target_dir, $options) = @_;
    $options->{untaint_pattern} ||= qr{^([-+@\w./]+)$};

    my $tainted_orig = cwd;
    my $orig;
    if ( $tainted_orig =~ $options->{untaint_pattern} ) {
      $orig = $1;
    }
    else {
      $orig = $tainted_orig;
    }

    my $tainted_dest;
    eval { $tainted_dest   = $target_dir ? abs_path( $target_dir ) : $orig };
    croak "Can't locate directory $target_dir: $@" if $@;

    my $dest;
    if ( $tainted_dest =~ $options->{untaint_pattern} ) {
      $dest = $1;
    }
    else {
      $dest = $tainted_dest;
    }

    if ($dest ne $orig) {
        chdir $dest or croak "Can't chdir to $dest\: $!";
    }

    my $self = bless {
        _pushd => $dest,
        _original => $orig
    }, __PACKAGE__;

    return $self;
}

#--------------------------------------------------------------------------#
# tempd()
#--------------------------------------------------------------------------#

sub tempd {
    my ($options) = @_;
    my $dir;
    eval { $dir = pushd( File::Temp::tempdir( CLEANUP => 0 ), $options ) };
    croak $@ if $@;
    $dir->{_tempd} = 1;
    return $dir;
}

#--------------------------------------------------------------------------#
# preserve()
#--------------------------------------------------------------------------#

sub preserve {
    my $self = shift;
    return 1 if ! $self->{"_tempd"};
    if ( @_ == 0 ) {
        return $self->{_preserve} = 1;
    }
    else {
        return $self->{_preserve} = $_[0] ? 1 : 0;
    }
}

#--------------------------------------------------------------------------#
# DESTROY()
# Revert to original directory as object is destroyed and cleanup
# if necessary
#--------------------------------------------------------------------------#

sub DESTROY {
    my ($self) = @_;
    my $orig = $self->{_original};
    chdir $orig if $orig; # should always be so, but just in case...
    if ( $self->{_tempd} &&
        !$self->{_preserve} ) {
        # don't destroy existing $@ if there is no error.
        my $err = do {
            local $@;
            eval { rmtree( $self->{_pushd} ) };
            $@;
        };
        carp $err if $err;
    }
}

1;

__END__

