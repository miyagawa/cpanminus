use strict;
use Test::More;
use xt::Run;
use File::Temp;
use File::Copy::Recursive qw(dircopy);

my $dir = File::Temp::tempdir;

dircopy("testdist/cpanfile_app_mirror/local-mirror",$dir);

open my $cpanfile, ">", "./testdist/cpanfile_app_mirror/cpanfile";
print $cpanfile <<EOF;
mirror 'file:/$dir';
requires 'Hash::MultiValue';
EOF

run_L "--mirror-only", "--installdeps", "./testdist/cpanfile_app_mirror";
like last_build_log, qr/file\:\/$dir/;

run_L "--mirror", "http://cpan.cpantesters.org", "--mirror-only", "--info", "Mojolicious";
like last_build_log, qr/cpan.cpantesters.org/;

run_L "--mirror", "http://cpan.cpantesters.org", "--from", "https://cpan.metacpan.org", "--info", "Mojolicious";
like last_build_log, qr/cpan.metacpan.org/;

run_L "--mirror", "http://cpan.cpantesters.org", "-M", "https://cpan.metacpan.org", "--info", "Mojolicious";
like last_build_log, qr/cpan.metacpan.org/;

done_testing;
