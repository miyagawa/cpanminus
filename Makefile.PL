use ExtUtils::MakeMaker;
WriteMakefile(
    NAME => 'App::cpanminus',
    VERSION_FROM => "lib/App/cpanminus.pm",
    PREREQ_PM => {
        'LWP' => 0,
        'Module::Build' => 0,
    },
    EXE_FILES => [ 'cpanm' ],
);
