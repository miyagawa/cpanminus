use inc::Module::Install;
name 'TestDist-DepFail';
version 0.1;

requires 'CPAN::Test::Dummy::Perl5::Build::Fails';
WriteAll;
