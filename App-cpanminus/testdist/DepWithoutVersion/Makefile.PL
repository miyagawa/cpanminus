use ExtUtils::MakeMaker;
WriteMakefile(
    NAME => "DepWithoutVersion",
    VERSION => "1.00",
    PREREQ_PM => {
        "Module::CPANfile::Requirement" => undef,
    },
);
