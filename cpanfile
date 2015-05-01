requires 'perl', '5.008000';

# bootstrap toolchain
requires 'Module::Build', 0.38;
requires 'ExtUtils::MakeMaker', 6.58;
requires 'ExtUtils::Install', 1.46;

requires 'CPAN::Common::Index', 0.006;
requires 'CPAN::DistnameInfo';
requires 'CPAN::Meta', '2.132830';
requires 'CPAN::Meta::Check';
requires 'CPAN::Meta::Requirements';
requires 'CPAN::Meta::YAML';
requires 'Class::Tiny', 1.001;
requires 'Digest::SHA';
requires 'Exporter', '5.63';
requires 'File::Temp';
requires 'File::Which';
requires 'File::pushd';
requires 'Getopt::Long';
requires 'HTTP::Tiny';
requires 'IPC::Run3';
requires 'JSON::PP';
requires 'Module::CPANfile';
requires 'Module::CoreList';
requires 'Module::Metadata';
requires 'Parse::CPAN::Meta';
requires 'Parse::PMFile', '0.26';
requires 'String::ShellQuote';
requires 'Win32::ShellQuote';
requires 'local::lib';
requires 'version';

# soft dependencies fro file downloading and uncompression
suggests 'LWP::Simple';
suggests 'LWP::UserAgent', '5.802';
suggests 'Archive::Tar';
suggests 'Archive::Zip';
suggests 'Compress::Zlib';
suggests 'File::HomeDir';
suggests 'Module::Signature';

on test => sub {
    requires 'Test::More', '0.96';
};

# build and xt/ test tools
on develop => sub {
    requires 'JSON';
    requires 'Module::Install';
    requires 'YAML';
    requires 'Capture::Tiny';
    requires 'Test::Requires';
};
