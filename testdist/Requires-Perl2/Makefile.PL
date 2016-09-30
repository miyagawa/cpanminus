use ExtUtils::MakeMaker;

my %args = (
    NAME => 'Requires::Perl2',
    VERSION => '0.01',
    ABSTRACT => 'blah blah blah',
    LICENSE => 'perl',
);

WriteMakefile(%args);

system 'cp', 'META.json', 'MYMETA.json';
