requires 'Module::Build', 0.36;
requires 'ExtUtils::MakeMaker', 6.31;
requires 'ExtUtils::Install', 1.46;

on test => sub {
    requires 'Test::More';
};

on develop => sub {
    requires 'App::FatPacker';
    requires 'CPAN::DistnameInfo';
    requires 'CPAN::Meta';
    requires 'CPAN::Meta::Check';
    requires 'CPAN::Meta::Prereqs';
    requires 'CPAN::Meta::Requirements';
    requires 'CPAN::Meta::YAML';
    requires 'Digest::SHA';
    requires 'Exporter', '5.63';
    requires 'File::Temp';
    requires 'File::pushd';
    requires 'Getopt::Long';
    requires 'HTTP::Tiny';
    requires 'JSON';
    requires 'JSON::PP';
    requires 'LWP::Simple';
    requires 'LWP::UserAgent', '5.802';
    requires 'Module::Install';
    requires 'Module::CPANfile';
    requires 'Module::CoreList';
    requires 'Module::Metadata';
    requires 'Parse::CPAN::Meta';
    requires 'String::ShellQuote';
    requires 'YAML';
    requires 'YAML::Tiny';
    requires 'aliased';
    requires 'local::lib';
    requires 'version';
    requires 'Capture::Tiny';
    requires 'Test::Requires';
    requires 'Test::More', '0.90';
    recommends 'Archive::Tar';
    recommends 'Archive::Zip';
    recommends 'Compress::Zlib';
    recommends 'File::HomeDir';
    recommends 'Module::Signature';
};
