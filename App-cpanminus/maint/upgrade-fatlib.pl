#!/usr/bin/env perl
use strict;
use Capture::Tiny qw(capture_stdout);
use Config;
use Cwd;
use CPAN::Meta;
use File::Path;
use File::Find;
use File::pushd;
use Carton::Snapshot;
use Tie::File;

# use 5.8.1 to see core version numbers
my $core_version = "5.008001";

# use 5.8.5 to run Carton since 5.8.1 is not supported there
my $plenv_version = "5.8.5";

sub run_command {
    local $ENV{PLENV_VERSION} = $plenv_version;
    system "plenv", "exec", @_;
}

sub rewrite_version_pm {
    my $file = shift;

    die "$file: $!" unless -e $file;
    
    tie my @file, 'Tie::File', $file or die $!;
    for (0..$#file) {
        if ($file[$_] =~ /^\s*eval "use version::vxs.*/) {
            splice @file, $_, 2, "    if (1) { # always pretend there's no XS";
            last;
        }
    }
}

sub build_snapshot {
    my $dir = shift;

    {
        my $pushd = pushd $dir;

        open my $fh, ">cpanfile";
        print $fh <<EOF;
requires 'Menlo', '$Menlo::VERSION';
requires 'Exporter', '5.59'; # only need 5.57, but force it in Carton for 5.8.5
EOF
        close $fh;
    
        run_command "carton", "install";
    }

    my $snapshot = Carton::Snapshot->new(path => "$dir/cpanfile.snapshot");
    $snapshot->load;

    return $snapshot;
}

sub required_modules {
    my($snapshot, $dir) = @_;
    
    my $requires = CPAN::Meta::Requirements->new;
    $requires->add_minimum(Menlo => $Menlo::VERSION);

    my $finder;
    $finder = sub {
        my $module = shift;

        my $dist = $snapshot->find($module);
        if ($dist) {
            my $name = $dist->name;
            my $path = "$dir/local/lib/perl5/$Config{archname}/.meta/$name/MYMETA.json";
            my $meta = CPAN::Meta->load_file($path);

            my $reqs = $meta->effective_prereqs->requirements_for('runtime' => 'requires');
            for my $module ( $reqs->required_modules ) {
                next if $module eq 'perl';

                my $core = $Module::CoreList::version{$core_version}{$module};
                unless ($core && $reqs->accepts_module($module, $core)) {
                    $requires->add_string_requirement( $module => $reqs->requirements_for_module($module) );
                    $finder->($module);
                }
            }
        }
    };

    $finder->("Menlo");
    $requires->clear_requirement($_) for qw( Module::CoreList ExtUtils::MakeMaker Carp );

    return map { s!::!/!g; "$_.pm" } $requires->required_modules;
}

sub pack_modules {
    my($dir, @modules) = @_;

    my $stdout = capture_stdout {
        local $ENV{PERL5LIB} = cwd . "/$dir/local/lib/perl5";
        run_command "fatpack", "packlists-for", @modules;
    };

    my @packlists = split /\n/, $stdout;
    for my $packlist (@packlists) {
        warn "Packing $packlist\n";
    }

    run_command "fatpack", "tree", @packlists;
}

sub run {
    my($fresh) = @_;

    my $dir = "fatpack-build";
    mkdir $dir, 0777;
    
    if ($fresh) {
        rmtree $dir;
        mkpath $dir;
    }

    my $snapshot = build_snapshot($dir);
    my @modules  = required_modules($snapshot, $dir);

    pack_modules($dir, @modules);

    mkpath "fatlib/version";

    for my $file (
        glob("fatlib/$Config{archname}/version.pm*"),
        glob("fatlib/$Config{archname}/version/*.pm"),
    ) {
        next if $file =~ /\bvxs\.pm$/;
        (my $target = $file) =~ s!^fatlib/$Config{archname}/!fatlib/!;
        rename $file => $target or die "$file => $target: $!";
    }

    rewrite_version_pm("fatlib/version.pm");

    rmtree("fatlib/$Config{archname}");
    rmtree("fatlib/POD2");

    find({ wanted => \&want, no_chdir => 1 }, "fatlib");
}

sub want {
    if (/\.pod$/) {
        print "rm $_\n";
        unlink $_;
    }
}

run(@ARGV);
