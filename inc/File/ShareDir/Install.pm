package File::ShareDir::Install;

use 5.008;
use strict;
use warnings;

use Carp;

use File::Spec;
use IO::Dir;

our $VERSION = '0.04';

our @DIRS;
our %TYPES;

require Exporter;

our @ISA = qw( Exporter);
our @EXPORT = qw( install_share );
our @EXPORT_OK = qw( postamble install_share );

#####################################################################
sub install_share
{
    my $dir  = @_ ? pop : 'share';
    my $type = @_ ? shift : 'dist';
    unless ( defined $type and $type eq 'module' or $type eq 'dist' ) {
        confess "Illegal or invalid share dir type '$type'";
    }
    unless ( defined $dir and -d $dir ) {
        confess "Illegal or missing directory '$dir'";
    }

    if( $type eq 'dist' and @_ ) {
        confess "Too many parameters to share_dir";
    }

    push @DIRS, $dir;
    $TYPES{$dir} = [ $type ];
    if( $type eq 'module' ) {
        my $module = _CLASS( $_[0] );
        unless ( defined $module ) {
            confess "Missing or invalid module name '$_[0]'";
        }
        push @{ $TYPES{$dir} }, $module;
    }

}

#####################################################################
sub postamble 
{
    my $self = shift;

    my @ret; # = $self->SUPER::postamble( @_ );
    foreach my $dir ( @DIRS ) {
        push @ret, __postamble_share_dir( $self, $dir, @{ $TYPES{ $dir } } );
    }
    return join "\n", @ret;
}

#####################################################################
sub __postamble_share_dir
{
    my( $self, $dir, $type, $mod ) = @_;

    my( $idir );
    if ( $type eq 'dist' ) {
        $idir = File::Spec->catdir( '$(INST_LIB)', 
                                    qw( auto share dist ), 
                                    '$(DISTNAME)'
                                  );
    } else {
        my $module = $mod;
        $module =~ s/::/-/g;
        $idir = File::Spec->catdir( '$(INST_LIB)', 
                                    qw( auto share module ), 
                                    $module
                                  );
    }

    my $files = {};
    _scan_share_dir( $files, $idir, $dir );

    my $autodir = '$(INST_LIB)';
    my $pm_to_blib = $self->oneliner(<<CODE, ['-MExtUtils::Install']);
pm_to_blib({\@ARGV}, '$autodir')
CODE

    my @cmds = $self->split_command( $pm_to_blib, %$files );

    my $r = join '', map { "\t\$(NOECHO) $_\n" } @cmds;

#    use Data::Dumper;
#    die Dumper $files;
    # Set up the install
    return "config::\n$r";
}


sub _scan_share_dir
{
    my( $files, $idir, $dir ) = @_;
    my $dh = IO::Dir->new( $dir ) or die "Unable to read $dir: $!";
    my $entry;
    while( defined( $entry = $dh->read ) ) {
        next if $entry =~ /^\./ or $entry =~ /(~|,v)$/;
        my $full = File::Spec->catfile( $dir, $entry );
        if( -f $full ) {
            $files->{ $full } = File::Spec->catfile( $idir, $entry );
        }
        elsif( -d $full ) {
            _scan_share_dir( $files, File::Spec->catdir( $idir, $entry ), $full );
        }
    }
}


#####################################################################
# Cloned from Params::Util::_CLASS
sub _CLASS ($) {
    (
        defined $_[0]
        and
        ! ref $_[0]
        and
        $_[0] =~ m/^[^\W\d]\w*(?:::\w+)*$/s
    ) ? $_[0] : undef;
}

1;
__END__

=head1 NAME

File::ShareDir::Install - Install shared files

=head1 SYNOPSIS

    use ExtUtils::MakeMaker;
    use File::ShareDir::Install;

    install_share 'share';
    install_share dist => 'dist-share';
    install_share module => 'My::Module' => 'other-share';

    WriteMakefile( ... );       # As you normaly would

    package MY;
    use File::ShareDir::Install qw(postamble);

=head1 DESCRIPTION

File::ShareDir::Install allows you to install read-only data files from a
distribution. It is a companion module to L<File::ShareDir>, which
allows you to locate these files after installation.

It is a port L<Module::Install::Share> to L<ExtUtils::MakeMaker> with the
improvement of only installing the files you want; C<.svn> and
other source-control junk will be ignored.

=head1 EXPORT

=head2 install_share

    install_share $dir;
    install_share dist => $dir;
    install_share module => $module, $dir;

Causes all the files in C<$dir> and its sub-directories.  to be installed
into a per-dist or per-module share directory.  Must be called before
L<WriteMakefile>.

The first 2 forms are equivalent.

The files will be installed when you run C<make install>.

To locate the files after installation so they can be used inside your
module, see  L<File::ShareDir>.

    my $dir = File::ShareDir::module_dir( $module );

Note that if you make multiple calls to C<install_share> on different
directories that contain the same filenames, the last of these calls takes
precedence.  In other words, if you do:

    install_share 'share1';
    install_share 'share2';

And both C<share1> and C<share2> contain a fill called C<info>, the file
C<share2/info> will be installed into your C<dist_dir()>.

=head2 postamble

Exported into the MY package.  Only documented here if you need to write your
own postable.

    package MY;
    use File::ShareDir::Install;

    sub postamble {
        my $self = shift;
        my @ret = File::ShareDir::Install::postamble( $self );
        # ... add more things to @ret;
        return join "\n", @ret;
    }

=head1 SEE ALSO

L<File::ShareDir>, L<Module::Install>.

=head1 AUTHOR

Philip Gwyn, E<lt>gwyn-AT-cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009-2011 by Philip Gwyn

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut
