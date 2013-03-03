
package CPAN::DistnameInfo;

$VERSION = "0.12";
use strict;

sub distname_info {
  my $file = shift or return;

  my ($dist, $version) = $file =~ /^
    ((?:[-+.]*(?:[A-Za-z0-9]+|(?<=\D)_|_(?=\D))*
     (?:
	[A-Za-z](?=[^A-Za-z]|$)
	|
	\d(?=-)
     )(?<![._-][vV])
    )+)(.*)
  $/xs or return ($file,undef,undef);

  if ($dist =~ /-undef\z/ and ! length $version) {
    $dist =~ s/-undef\z//;
  }

  # Remove potential -withoutworldwriteables suffix
  $version =~ s/-withoutworldwriteables$//;

  if ($version =~ /^(-[Vv].*)-(\d.*)/) {
   
    # Catch names like Unicode-Collate-Standard-V3_1_1-0.1
    # where the V3_1_1 is part of the distname
    $dist .= $1;
    $version = $2;
  }

  if ($version =~ /(.+_.*)-(\d.*)/) {
      # Catch names like Task-Deprecations5_14-1.00.tar.gz where the 5_14 is
      # part of the distname. However, names like libao-perl_0.03-1.tar.gz
      # should still have 0.03-1 as their version.
      $dist .= $1;
      $version = $2;
  }

  # Normalize the Dist.pm-1.23 convention which CGI.pm and
  # a few others use.
  $dist =~ s{\.pm$}{};

  $version = $1
    if !length $version and $dist =~ s/-(\d+\w)$//;

  $version = $1 . $version
    if $version =~ /^\d+$/ and $dist =~ s/-(\w+)$//;

  if ($version =~ /\d\.\d/) {
    $version =~ s/^[-_.]+//;
  }
  else {
    $version =~ s/^[-_]+//;
  }

  my $dev;
  if (length $version) {
    if ($file =~ /^perl-?\d+\.(\d+)(?:\D(\d+))?(-(?:TRIAL|RC)\d+)?$/) {
      $dev = 1 if (($1 > 6 and $1 & 1) or ($2 and $2 >= 50)) or $3;
    }
    elsif ($version =~ /\d\D\d+_\d/ or $version =~ /-TRIAL/) {
      $dev = 1;
    }
  }
  else {
    $version = undef;
  }

  ($dist, $version, $dev);
}

sub new {
  my $class = shift;
  my $distfile = shift;

  $distfile =~ s,//+,/,g;

  my %info = ( pathname => $distfile );

  ($info{filename} = $distfile) =~ s,^(((.*?/)?authors/)?id/)?([A-Z])/(\4[A-Z])/(\5[-A-Z0-9]*)/,,
    and $info{cpanid} = $6;

  if ($distfile =~ m,([^/]+)\.(tar\.(?:g?z|bz2)|zip|tgz)$,i) { # support more ?
    $info{distvname} = $1;
    $info{extension} = $2;
  }

  @info{qw(dist version beta)} = distname_info($info{distvname});
  $info{maturity} = delete $info{beta} ? 'developer' : 'released';

  return bless \%info, $class;
}

sub dist      { shift->{dist} }
sub version   { shift->{version} }
sub maturity  { shift->{maturity} }
sub filename  { shift->{filename} }
sub cpanid    { shift->{cpanid} }
sub distvname { shift->{distvname} }
sub extension { shift->{extension} }
sub pathname  { shift->{pathname} }

sub properties { %{ $_[0] } }

1;

__END__

