#line 1
package Module::Install::ReadmeFromPod;

use 5.006;
use strict;
use warnings;
use base qw(Module::Install::Base);
use vars qw($VERSION);

$VERSION = '0.18';

sub readme_from {
  my $self = shift;
  return unless $self->is_admin;

  # Input file
  my $in_file  = shift || $self->_all_from
    or die "Can't determine file to make readme_from";

  # Get optional arguments
  my ($clean, $format, $out_file, $options);
  my $args = shift;
  if ( ref $args ) {
    # Arguments are in a hashref
    if ( ref($args) ne 'HASH' ) {
      die "Expected a hashref but got a ".ref($args)."\n";
    } else {
      $clean    = $args->{'clean'};
      $format   = $args->{'format'};
      $out_file = $args->{'output_file'};
      $options  = $args->{'options'};
    }
  } else {
    # Arguments are in a list
    $clean    = $args;
    $format   = shift;
    $out_file = shift;
    $options  = \@_;
  }

  # Default values;
  $clean  ||= 0;
  $format ||= 'txt';

  # Generate README
  print "readme_from $in_file to $format\n";
  if ($format =~ m/te?xt/) {
    $out_file = $self->_readme_txt($in_file, $out_file, $options);
  } elsif ($format =~ m/html?/) {
    $out_file = $self->_readme_htm($in_file, $out_file, $options);
  } elsif ($format eq 'man') {
    $out_file = $self->_readme_man($in_file, $out_file, $options);
  } elsif ($format eq 'pdf') {
    $out_file = $self->_readme_pdf($in_file, $out_file, $options);
  }

  if ($clean) {
    $self->clean_files($out_file);
  }

  return 1;
}


sub _readme_txt {
  my ($self, $in_file, $out_file, $options) = @_;
  $out_file ||= 'README';
  require Pod::Text;
  my $parser = Pod::Text->new( @$options );
  open my $out_fh, '>', $out_file or die "Could not write file $out_file:\n$!\n";
  $parser->output_fh( *$out_fh );
  $parser->parse_file( $in_file );
  close $out_fh;
  return $out_file;
}


sub _readme_htm {
  my ($self, $in_file, $out_file, $options) = @_;
  $out_file ||= 'README.htm';
  require Pod::Html;
  Pod::Html::pod2html(
    "--infile=$in_file",
    "--outfile=$out_file",
    @$options,
  );
  # Remove temporary files if needed
  for my $file ('pod2htmd.tmp', 'pod2htmi.tmp') {
    if (-e $file) {
      unlink $file or warn "Warning: Could not remove file '$file'.\n$!\n";
    }
  }
  return $out_file;
}


sub _readme_man {
  my ($self, $in_file, $out_file, $options) = @_;
  $out_file ||= 'README.1';
  require Pod::Man;
  my $parser = Pod::Man->new( @$options );
  $parser->parse_from_file($in_file, $out_file);
  return $out_file;
}


sub _readme_pdf {
  my ($self, $in_file, $out_file, $options) = @_;
  $out_file ||= 'README.pdf';
  eval { require App::pod2pdf; }
    or die "Could not generate $out_file because pod2pdf could not be found\n";
  my $parser = App::pod2pdf->new( @$options );
  $parser->parse_from_file($in_file);
  open my $out_fh, '>', $out_file or die "Could not write file $out_file:\n$!\n";
  select $out_fh;
  $parser->output;
  select STDOUT;
  close $out_fh;
  return $out_file;
}


sub _all_from {
  my $self = shift;
  return unless $self->admin->{extensions};
  my ($metadata) = grep {
    ref($_) eq 'Module::Install::Metadata';
  } @{$self->admin->{extensions}};
  return unless $metadata;
  return $metadata->{values}{all_from} || '';
}

'Readme!';

__END__

#line 254

