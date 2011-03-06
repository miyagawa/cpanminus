use ExtUtils::MakeMaker;
WriteMakefile(
    NAME => "DepWithoutVersion",
    VERSION => "1.00",
    PREREQ_PM => {
        "Plack::Handler" => undef,
    },
);
