use ExtUtils::MakeMaker;
WriteMakefile(
    NAME => "SelfDep",
    VERSION => "1.00",
    PREREQ_PM => {
        "SelfDep" => "0",
        "SelfDep::Also" => "0",
    },
);
