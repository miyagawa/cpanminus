package Menlo::Index::Mirror;
use strict;
use parent qw(CPAN::Common::Index::Mirror);
use Class::Tiny qw(fetcher);

use File::Basename ();
use File::Spec ();
use URI ();
use IO::Uncompress::Gunzip ();

my %INDICES = (
    mailrc   => 'authors/01mailrc.txt.gz',
    packages => 'modules/02packages.details.txt.gz',
);

sub refresh_index {
    my $self = shift;
    for my $file ( values %INDICES ) {
        my $remote = URI->new_abs( $file, $self->mirror );
        my $local = File::Spec->catfile( $self->cache, File::Basename::basename($file) );
        $self->fetcher->($remote, $local)
          or Carp::croak( "Cannot fetch $remote to $local");
        ( my $uncompressed = $local ) =~ s/\.gz$//;
        IO::Uncompress::Gunzip::gunzip( $local, $uncompressed )
          or Carp::croak "gunzip failed: $IO::Uncompress::Gunzip::GunzipError\n";
    }
}

1;
