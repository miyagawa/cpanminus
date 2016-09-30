use strict;
use xt::Run;
use Test::More;

{
    my $out = run '--showdeps', './testdist/Spreadsheet-Read-0.48';
    like $out, qr/Test::NoWarnings/;
    unlike $out, qr/CSV_XS/;
}

{
    my $out = run '--showdeps', './testdist/Spreadsheet-Read-0.48', '--with-feature=opt_csv';
    like $out, qr/CSV_XS/;
}

{
    my $out = run '--showdeps', './testdist/Spreadsheet-Read-0.48', '--with-all-features';
    like $out, qr/CSV_XS/;
    like $out, qr/XLSX/;
}

{
    my $out = run '--showdeps', './testdist/Spreadsheet-Read-0.48', '--with-all-features', '--without-feature=opt_csv';
    unlike $out, qr/CSV_XS/;
    like $out, qr/XLSX/;
}

done_testing;
