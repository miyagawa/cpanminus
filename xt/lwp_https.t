use strict;
use xt::Run;
use Test::More;
use Module::Metadata;

my $has_https = Module::Metadata->new_from_module('LWP::Protocol::https');
system 'cpanm', '-Uf', 'LWP::Protocol::https' if $has_https;

run '--mirror', 'https://cpan.metacpan.org', 'Hash::MultiValue';
unlike last_build_log, qr/You have LWP/;

run '--mirror', 'http://cpan.metacpan.org', 'Hash::MultiValue';
like last_build_log, qr/You have LWP/;

run 'LWP::Protocol::https' if $has_https;

done_testing;
