
use strict;
use warnings;



use ExtUtils::MakeMaker 6.30;

# perl Makefile.PL (from git repo) copies 'cpanm' -> 'bin/cpanm'
if (-e 'cpanm') {
    print STDERR "Generating bin/cpanm from cpanm\n";
    open my $in,  "<cpanm"     or die $!;
    open my $out, ">bin/cpanm" or die $!;
    while (<$in>) {
        s|^#!/usr/bin/env perl|#!perl|; # so MakeMaker can fix it
        print $out $_;
    }
}




my %WriteMakefileArgs = (
  "ABSTRACT" => "get, unpack, build and install modules from CPAN",
  "AUTHOR" => "- Tatsuhiko Miyagawa",
  "BUILD_REQUIRES" => {},
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "DISTNAME" => "App-cpanminus",
  "EXE_FILES" => [
    "bin/cpanm"
  ],
  "LICENSE" => "perl",
  "NAME" => "App::cpanminus",
  "PREREQ_PM" => {
    "ExtUtils::Install" => "1.46",
    "ExtUtils::MakeMaker" => "6.31",
    "Module::Build" => "0.36"
  },
  "TEST_REQUIRES" => {
    "Test::More" => 0
  },
  "VERSION" => "1.6911",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  my $tr = delete $WriteMakefileArgs{TEST_REQUIRES};
  my $br = $WriteMakefileArgs{BUILD_REQUIRES};
  for my $mod ( keys %$tr ) {
    if ( exists $br->{$mod} ) {
      $br->{$mod} = $tr->{$mod} if $tr->{$mod} > $br->{$mod};
    }
    else {
      $br->{$mod} = $tr->{$mod};
    }
  }
}

unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



