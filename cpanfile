requires 'perl', '5.008001';

# runtime dependencies. Mostly core and fatpackable back to 5.8
# https://github.com/miyagawa/cpanminus/issues/455
requires 'CPAN::Common::Index', 0.006;
requires 'CPAN::DistnameInfo';
requires 'CPAN::Meta', '2.132830';
requires 'CPAN::Meta::Check';
requires 'CPAN::Meta::Requirements';
requires 'CPAN::Meta::YAML';
requires 'Capture::Tiny';
requires 'Class::Tiny', 1.001;
requires 'Exporter';
requires 'File::Temp';
requires 'File::Which';
requires 'File::pushd';
requires 'Getopt::Long';
requires 'HTTP::Tiny', '0.054';
requires 'HTTP::Tinyish', '0.04';
requires 'IPC::Run3';
requires 'JSON::PP';
requires 'Module::Build::Tiny';
requires 'Module::CPANfile';
requires 'Module::CoreList';
requires 'Module::Metadata';
requires 'Parse::CPAN::Meta';
requires 'Parse::PMFile', '0.26';
requires 'String::ShellQuote';
requires 'Win32::ShellQuote';
requires 'local::lib';
requires 'version';

# soft dependencies for optional features
suggests 'LWP::UserAgent', '5.802';
suggests 'Archive::Tar';
suggests 'Archive::Zip';
suggests 'File::HomeDir';
suggests 'Module::Signature';
suggests 'Digest::SHA';

on test => sub {
    requires 'Test::More', '0.96';
};

# build and xt/ test tools
on develop => sub {
    requires 'JSON';
    requires 'Module::Install';
    requires 'Test::Requires';
};
