package Menlo::Legacy;

use strict;
use 5.008_005;
our $VERSION = '1.9018';

1;
__END__

=encoding utf-8

=head1 NAME

Menlo::Legacy - Legacy internal and client support for Menlo

=head1 SYNOPSIS

  use Menlo::CLI::Compat;

  my $app = Menlo::CLI::Compat->new;
  $app->parse_options(@ARGV);
  $app->run;

=head1 DESCRIPTION

Menlo::Legacy is a package to install L<Menlo::CLI::Compat> which is a
compatibility library that implements the classic versino of
cpanminus, so that existing users of cpanm and API clients who depend
on the internals of cpanm (e.g. L<Carton>, L<Carmel> and L<App::cpm>)
can rely on the stable feature of cpanm. This way Menlo core can
evolve and refactor without breaking the downstream clients, including
C<cpanm> itself.

=head1 AUTHOR

Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt>

=head1 COPYRIGHT

Copyright 2018- Tatsuhiko Miyagawa

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Menlo::CLI::Compat>

=cut
