use ExtUtils::MakeMaker;
WriteMakefile(
    NAME => 'App::cpanminus',
    VERSION_FROM => "lib/App/cpanminus.pm",
    ABSTRACT => 'Get, unpack, build and install modules from CPAN.',
    PREREQ_PM => {
        'LWP' => 0,
        'Module::Build' => 0,
    },
    EXE_FILES => [ 'cpanm' ],
);
