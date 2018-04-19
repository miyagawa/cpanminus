requires 'perl', '5.008001';

on test => sub {
    requires 'Test::More';
};

on develop => sub {
    requires 'Menlo', '1.9006';

    requires 'JSON';
    requires 'Module::Install';
    requires 'Test::Requires';

    # for fatpacking
    requires 'App::FatPacker';
    requires 'Perl::Strip';
    requires 'Tie::File';

    recommends 'Archive::Tar';
    recommends 'Archive::Zip';
    recommends 'Compress::Zlib';
    recommends 'File::HomeDir';
    recommends 'LWP::UserAgent', '5.802';
    recommends 'Module::Signature';
};
