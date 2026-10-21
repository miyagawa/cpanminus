package Menlo::Index::Mirror;
use strict;
use parent qw(CPAN::Common::Index::Mirror);
use Class::Tiny qw(fetcher);

use File::Basename ();
use File::Spec ();
use URI ();

our $HAS_IO_UNCOMPRESS_GUNZIP = eval { require IO::Uncompress::Gunzip };

my %INDICES = (
#    mailrc   => 'authors/01mailrc.txt.gz',
    packages => 'modules/02packages.details.txt.gz',
);

sub refresh_index {
    my $self = shift;
    for my $file ( values %INDICES ) {
        my $remote = URI->new_abs( $file, $self->mirror );
        $remote =~ s/\.gz$//
          unless $HAS_IO_UNCOMPRESS_GUNZIP;
        my $local = File::Spec->catfile( $self->cache, File::Basename::basename($file) );
        # fetcher returns true on success. Menlo::CLI::Compat in Menlo-Legacy 1.9022
        # and earlier returned an HTTP::Tinyish response hash, which is always true
        my $res = $self->fetcher->($remote, $local);
        my $ok  = ref $res eq 'HASH' ? $res->{success} : $res;
        unless ($ok) {
            my $why = ref $res eq 'HASH' ? ": $res->{status} $res->{reason}" : "";
            Carp::croak( "Cannot fetch $remote to $local$why");
        }
        if ($HAS_IO_UNCOMPRESS_GUNZIP) {
            ( my $uncompressed = $local ) =~ s/\.gz$//;
            IO::Uncompress::Gunzip::gunzip( $local, $uncompressed )
              or Carp::croak "gunzip failed: $IO::Uncompress::Gunzip::GunzipError\n";
        }
    }
}

1;

__END__

=head1 NAME

Menlo::Index::Mirror - CPAN::Common::Index::Mirror with a custom fetcher

=head1 SYNOPSIS

  my $index = Menlo::Index::Mirror->new({
      mirror  => "https://cpan.metacpan.org/",
      cache   => $dir,
      fetcher => sub { my($uri, $local) = @_; ... },
  });

=head1 DESCRIPTION

C<fetcher> is called with the remote URI and the local path to save it to.
It should return true on success (including when the local copy is already
up to date) and false on failure. An HTTP::Tinyish response hash is also
accepted, in which case its C<success> field is checked.

=cut
