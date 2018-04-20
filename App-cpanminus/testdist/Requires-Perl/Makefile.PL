use ExtUtils::MakeMaker;

my %args = (
    NAME => 'Requires::Perl',
    VERSION => '0.01',
    ABSTRACT => 'blah blah blah',
    MIN_PERL_VERSION => '5.30.0',
    LICENSE => 'perl',
);

WriteMakefile(%args);
