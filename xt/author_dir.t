use strict;
use xt::Run;
use Test::More;

run 'JV/Getopt-Long-2.39.tar.gz';
like last_build_log, qr!Fetching .*/J/JV/JV/Getopt!;

run 'J/JV/JV/Getopt-Long-2.39.tar.gz';
like last_build_log, qr!Fetching .*/J/JV/JV/Getopt!;

run 'DOY/Try-Tiny-0.12.tar.gz';
like last_build_log, qr!Fetching .*/D/DO/DOY/Try-Tiny!;

run 'D/DO/DOY/Try-Tiny-0.12.tar.gz';
like last_build_log, qr!Fetching .*/D/DO/DOY/Try-Tiny!;

done_testing;
