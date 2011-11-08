package App::cpanminus::script;
use strict;
use Config;
use Cwd ();
use File::Basename ();
use File::Find ();
use File::Path ();
use File::Spec ();
use File::Copy ();
use Getopt::Long ();
use Parse::CPAN::Meta;
use Symbol ();

use constant WIN32 => $^O eq 'MSWin32';
use constant SUNOS => $^O eq 'solaris';

our $VERSION = "1.5004";

my $quote = WIN32 ? q/"/ : q/'/;

sub new {
    my $class = shift;

    bless {
        home => "$ENV{HOME}/.cpanm",
        cmd  => 'install',
        seen => {},
        notest => undef,
        installdeps => undef,
        force => undef,
        sudo => undef,
        make  => undef,
        verbose => undef,
        quiet => undef,
        interactive => undef,
        log => undef,
        mirrors => [],
        mirror_only => undef,
        mirror_index => undef,
        perl => $^X,
        argv => [],
        local_lib => undef,
        self_contained => undef,
        prompt_timeout => 0,
        prompt => undef,
        configure_timeout => 60,
        try_lwp => 1,
        try_wget => 1,
        try_curl => 1,
        uninstall_shadows => ($] < 5.012),
        skip_installed => 1,
        skip_satisfied => 0,
        auto_cleanup => 7, # days
        pod2man => 1,
        installed_dists => 0,
        showdeps => 0,
        scandeps => 0,
        scandeps_tree => [],
        format   => 'tree',
        save_dists => undef,
        skip_configure => 0,
        @_,
    }, $class;
}

sub env {
    my($self, $key) = @_;
    $ENV{"PERL_CPANM_" . $key};
}

sub parse_options {
    my $self = shift;

    local @ARGV = @{$self->{argv}};
    push @ARGV, split /\s+/, $self->env('OPT');
    push @ARGV, @_;

    Getopt::Long::Configure("bundling");
    Getopt::Long::GetOptions(
        'f|force'   => sub { $self->{skip_installed} = 0; $self->{force} = 1 },
        'n|notest!' => \$self->{notest},
        'S|sudo!'   => \$self->{sudo},
        'v|verbose' => sub { $self->{verbose} = $self->{interactive} = 1 },
        'q|quiet!'  => \$self->{quiet},
        'h|help'    => sub { $self->{action} = 'show_help' },
        'V|version' => sub { $self->{action} = 'show_version' },
        'perl=s'    => \$self->{perl},
        'l|local-lib=s' => sub { $self->{local_lib} = $self->maybe_abs($_[1]) },
        'L|local-lib-contained=s' => sub {
            $self->{local_lib} = $self->maybe_abs($_[1]);
            $self->{self_contained} = 1;
            $self->{pod2man} = undef;
        },
        'mirror=s@' => $self->{mirrors},
        'mirror-only!' => \$self->{mirror_only},
        'mirror-index=s'  => sub { $self->{mirror_index} = $_[1]; $self->{mirror_only} = 1 },
        'cascade-search!' => \$self->{cascade_search},
        'prompt!'   => \$self->{prompt},
        'installdeps' => \$self->{installdeps},
        'skip-installed!' => \$self->{skip_installed},
        'skip-satisfied!' => \$self->{skip_satisfied},
        'reinstall'    => sub { $self->{skip_installed} = 0 },
        'interactive!' => \$self->{interactive},
        'i|install' => sub { $self->{cmd} = 'install' },
        'info'      => sub { $self->{cmd} = 'info' },
        'look'      => sub { $self->{cmd} = 'look'; $self->{skip_installed} = 0 },
        'self-upgrade' => sub { $self->{cmd} = 'install'; $self->{skip_installed} = 1; push @ARGV, 'App::cpanminus' },
        'uninst-shadows!'  => \$self->{uninstall_shadows},
        'lwp!'    => \$self->{try_lwp},
        'wget!'   => \$self->{try_wget},
        'curl!'   => \$self->{try_curl},
        'auto-cleanup=s' => \$self->{auto_cleanup},
        'man-pages!' => \$self->{pod2man},
        'scandeps'   => \$self->{scandeps},
        'showdeps'   => sub { $self->{showdeps} = 1; $self->{skip_installed} = 0 },
        'format=s'   => \$self->{format},
        'save-dists=s' => sub {
            $self->{save_dists} = $self->maybe_abs($_[1]);
        },
        'skip-configure!' => \$self->{skip_configure},
        'metacpan'   => \$self->{metacpan},
    );

    if (!@ARGV && $0 ne '-' && !-t STDIN){ # e.g. # cpanm < author/requires.cpanm
        push @ARGV, $self->load_argv_from_fh(\*STDIN);
        $self->{load_from_stdin} = 1;
    }

    $self->{argv} = \@ARGV;
}

sub check_libs {
    my $self = shift;
    return if $self->{_checked}++;

    $self->bootstrap_local_lib;
    if (@{$self->{bootstrap_deps} || []}) {
        local $self->{notest} = 1; # test failure in bootstrap should be tolerated
        local $self->{scandeps} = 0;
        $self->install_deps(Cwd::cwd, 0, @{$self->{bootstrap_deps}});
    }
}

sub doit {
    my $self = shift;

    $self->setup_home;
    $self->init_tools;

    if (my $action = $self->{action}) {
        $self->$action() and return 1;
    }

    $self->show_help(1)
        unless @{$self->{argv}} or $self->{load_from_stdin};

    $self->configure_mirrors;

    my @fail;
    for my $module (@{$self->{argv}}) {
        if ($module =~ s/\.pm$//i) {
            my ($volume, $dirs, $file) = File::Spec->splitpath($module);
            $module = join '::', grep { $_ } File::Spec->splitdir($dirs), $file;
        }

        ($module, my $version) = split /\~/, $module, 2;
        if ($self->{skip_satisfied} or defined $version) {
            $self->check_libs;
            my($ok, $local) = $self->check_module($module, $version || 0);
            if ($ok) {
                $self->diag("You have $module (" . ($local || 'undef') . ")\n", 1);
                next;
            }
        }

        $self->install_module($module, 0, $version)
            or push @fail, $module;
    }

    if ($self->{base} && $self->{auto_cleanup}) {
        $self->cleanup_workdirs;
    }

    if ($self->{installed_dists}) {
        my $dists = $self->{installed_dists} > 1 ? "distributions" : "distribution";
        $self->diag("$self->{installed_dists} $dists installed\n", 1);
    }

    if ($self->{scandeps}) {
        $self->dump_scandeps();
    }

    return !@fail;
}

sub setup_home {
    my $self = shift;

    $self->{home} = $self->env('HOME') if $self->env('HOME');

    unless (_writable($self->{home})) {
        die "Can't write to cpanm home '$self->{home}': You should fix it with chown/chmod first.\n";
    }

    $self->{base} = "$self->{home}/work/" . time . ".$$";
    File::Path::mkpath([ $self->{base} ], 0, 0777);

    my $link = "$self->{home}/latest-build";
    eval { unlink $link; symlink $self->{base}, $link };

    $self->{log} = File::Spec->catfile($self->{home}, "build.log"); # because we use shell redirect

    {
        my $log = $self->{log}; my $base = $self->{base};
        $self->{at_exit} = sub {
            my $self = shift;
            File::Copy::copy($self->{log}, "$self->{base}/build.log");
        };
    }

    { open my $out, ">$self->{log}" or die "$self->{log}: $!" }

    $self->chat("cpanm (App::cpanminus) $VERSION on perl $] built for $Config{archname}\n" .
                "Work directory is $self->{base}\n");
}

sub fetch_meta_sco {
    my($self, $dist) = @_;
    return if $self->{mirror_only};

    my $meta_yml = $self->get("http://search.cpan.org/meta/$dist->{distvname}/META.yml");
    return $self->parse_meta_string($meta_yml);
}

sub package_index_for {
    my ($self, $mirror) = @_;
    return $self->source_for($mirror) . "/02packages.details.txt";
}

sub generate_mirror_index {
    my ($self, $mirror) = @_;
    my $file = $self->package_index_for($mirror);
    my $gz_file = $file . '.gz';
    my $index_mtime = (stat $gz_file)[9];

    unless (-e $file && (stat $file)[9] >= $index_mtime) {
        $self->chat("Uncompressing index file...\n");
        if (eval {require Compress::Zlib}) {
            my $gz = Compress::Zlib::gzopen($gz_file, "rb")
                or do { $self->diag_fail("$Compress::Zlib::gzerrno opening compressed index"); return};
            open my $fh, '>', $file
                or do { $self->diag_fail("$! opening uncompressed index for write"); return };
            my $buffer;
            while (my $status = $gz->gzread($buffer)) {
                if ($status < 0) {
                    $self->diag_fail($gz->gzerror . " reading compressed index");
                    return;
                }
                print $fh $buffer;
            }
        } else {
            if (system("gunzip -c $gz_file > $file")) {
                $self->diag_fail("Cannot uncompress -- please install gunzip or Compress::Zlib");
                return;
            }
        }
        utime $index_mtime, $index_mtime, $file;
    }
    return 1;
}

sub search_mirror_index {
    my ($self, $mirror, $module, $version) = @_;
    $self->search_mirror_index_file($self->package_index_for($mirror), $module, $version);
}

sub search_mirror_index_file {
    my($self, $file, $module, $version) = @_;

    open my $fh, '<', $file or return;
    my $found;
    while (<$fh>) {
        if (m!^\Q$module\E\s+([\w\.]+)\s+(.*)!m) {
            $found = $self->cpan_module($module, $2, $1);
            last;
        }
    }

    return $found unless $self->{cascade_search};

    if ($found) {
        if (!$version or
            version->new($found->{version} || 0) >= version->new($version)) {
            return $found;
        } else {
            $self->chat("Found $module version $found->{version} < $version.\n");
        }
    }

    return;
}

sub search_module {
    my($self, $module, $version) = @_;

    unless ($self->{mirror_only}) {
        if ($self->{metacpan}) {
            require JSON::PP;
            $self->chat("Searching $module on metacpan ...\n");
            my $module_uri  = "http://api.metacpan.org/module/$module";
            my $module_json = $self->get($module_uri);
            my $module_meta = eval { JSON::PP::decode_json($module_json) };
            if ($module_meta && $module_meta->{distribution}) {
                my $dist_uri = "http://api.metacpan.org/release/$module_meta->{distribution}";
                my $dist_json = $self->get($dist_uri);
                my $dist_meta = eval { JSON::PP::decode_json($dist_json) };
                if ($dist_meta && $dist_meta->{download_url}) {
                    (my $distfile = $dist_meta->{download_url}) =~ s!.+/authors/id/!!;
                    local $self->{mirrors} = $self->{mirrors};
                    if ($dist_meta->{stat}->{mtime} > time()-24*60*60) {
                        $self->{mirrors} = ['http://cpan.metacpan.org'];
                    }
                    return $self->cpan_module($module, $distfile, $dist_meta->{version});
                }
            }
            $self->diag_fail("Finding $module on metacpan failed.");
        }

        $self->chat("Searching $module on cpanmetadb ...\n");
        my $uri  = "http://cpanmetadb.appspot.com/v1.0/package/$module";
        my $yaml = $self->get($uri);
        my $meta = $self->parse_meta_string($yaml);
        if ($meta && $meta->{distfile}) {
            return $self->cpan_module($module, $meta->{distfile}, $meta->{version});
        }

        $self->diag_fail("Finding $module on cpanmetadb failed.");

        $self->chat("Searching $module on search.cpan.org ...\n");
        my $uri  = "http://search.cpan.org/perldoc?$module";
        my $html = $self->get($uri);
        $html =~ m!<a href="/CPAN/authors/id/(.*?\.(?:tar\.gz|tgz|tar\.bz2|zip))">!
            and return $self->cpan_module($module, $1);

        $self->diag_fail("Finding $module on search.cpan.org failed.");
    }

    if ($self->{mirror_index}) {
        $self->chat("Searching $module on mirror index $self->{mirror_index} ...\n");
        my $pkg = $self->search_mirror_index_file($self->{mirror_index}, $module, $version);
        return $pkg if $pkg;
    }

    MIRROR: for my $mirror (@{ $self->{mirrors} }) {
        $self->chat("Searching $module on mirror $mirror ...\n");
        my $name = '02packages.details.txt.gz';
        my $uri  = "$mirror/modules/$name";
        my $gz_file = $self->package_index_for($mirror) . '.gz';

        unless ($self->{pkgs}{$uri}) {
            $self->chat("Downloading index file $uri ...\n");
            $self->mirror($uri, $gz_file);
            $self->generate_mirror_index($mirror) or next MIRROR;
            $self->{pkgs}{$uri} = "!!retrieved!!";
        }

        my $pkg = $self->search_mirror_index($mirror, $module, $version);
        return $pkg if $pkg;

        $self->diag_fail("Finding $module ($version) on mirror $mirror failed.");
    }

    return;
}

sub source_for {
    my($self, $mirror) = @_;
    $mirror =~ s/[^\w\.\-]+/%/g;

    my $dir = "$self->{home}/sources/$mirror";
    File::Path::mkpath([ $dir ], 0, 0777);

    return $dir;
}

sub load_argv_from_fh {
    my($self, $fh) = @_;

    my @argv;
    while(defined(my $line = <$fh>)){
        chomp $line;
        $line =~ s/#.+$//; # comment
        $line =~ s/^\s+//; # trim spaces
        $line =~ s/\s+$//; # trim spaces

        push @argv, split ' ', $line if $line;
    }
    return @argv;
}

sub show_version {
    print "cpanm (App::cpanminus) version $VERSION\n";
    return 1;
}

sub show_help {
    my $self = shift;

    if ($_[0]) {
        die <<USAGE;
Usage: cpanm [options] Module [...]

Try `cpanm --help` or `man cpanm` for more options.
USAGE
    }

    print <<HELP;
Usage: cpanm [options] Module [...]

Options:
  -v,--verbose              Turns on chatty output
  -q,--quiet                Turns off the most output
  --interactive             Turns on interactive configure (required for Task:: modules)
  -f,--force                force install
  -n,--notest               Do not run unit tests
  -S,--sudo                 sudo to run install commands
  --installdeps             Only install dependencies
  --showdeps                Only display direct dependencies
  --reinstall               Reinstall the distribution even if you already have the latest version installed
  --mirror                  Specify the base URL for the mirror (e.g. http://cpan.cpantesters.org/)
  --mirror-only             Use the mirror's index file instead of the CPAN Meta DB
  --prompt                  Prompt when configure/build/test fails
  -l,--local-lib            Specify the install base to install modules
  -L,--local-lib-contained  Specify the install base to install all non-core modules
  --auto-cleanup            Number of days that cpanm's work directories expire in. Defaults to 7

Commands:
  --self-upgrade            upgrades itself
  --info                    Displays distribution info on CPAN
  --look                    Opens the distribution with your SHELL
  -V,--version              Displays software version

Examples:

  cpanm Test::More                                          # install Test::More
  cpanm MIYAGAWA/Plack-0.99_05.tar.gz                       # full distribution path
  cpanm http://example.org/LDS/CGI.pm-3.20.tar.gz           # install from URL
  cpanm ~/dists/MyCompany-Enterprise-1.00.tar.gz            # install from a local file
  cpanm --interactive Task::Kensho                          # Configure interactively
  cpanm .                                                   # install from local directory
  cpanm --installdeps .                                     # install all the deps for the current directory
  cpanm -L extlib Plack                                     # install Plack and all non-core deps into extlib
  cpanm --mirror http://cpan.cpantesters.org/ DBI           # use the fast-syncing mirror

You can also specify the default options in PERL_CPANM_OPT environment variable in the shell rc:

  export PERL_CPANM_OPT="--prompt --reinstall -l ~/perl --mirror http://cpan.cpantesters.org"

Type `man cpanm` or `perldoc cpanm` for the more detailed explanation of the options.

HELP

    return 1;
}

sub _writable {
    my $dir = shift;
    my @dir = File::Spec->splitdir($dir);
    while (@dir) {
        $dir = File::Spec->catdir(@dir);
        if (-e $dir) {
            return -w _;
        }
        pop @dir;
    }

    return;
}

sub maybe_abs {
    my($self, $lib) = @_;
    return $lib if $lib eq '_'; # special case: gh-113
    $lib =~ /^[~\/]/ ? $lib : File::Spec->canonpath(Cwd::cwd . "/$lib");
}

sub bootstrap_local_lib {
    my $self = shift;

    # If -l is specified, use that.
    if ($self->{local_lib}) {
        return $self->setup_local_lib($self->{local_lib});
    }

    # root, locally-installed perl or --sudo: don't care about install_base
    return if $self->{sudo} or (_writable($Config{installsitelib}) and _writable($Config{installsitebin}));

    # local::lib is configured in the shell -- yay
    if ($ENV{PERL_MM_OPT} and ($ENV{MODULEBUILDRC} or $ENV{PERL_MB_OPT})) {
        $self->bootstrap_local_lib_deps;
        return;
    }

    $self->setup_local_lib;

    $self->diag(<<DIAG);
!
! Can't write to $Config{installsitelib} and $Config{installsitebin}: Installing modules to $ENV{HOME}/perl5
! To turn off this warning, you have to do one of the following:
!   - run me as a root or with --sudo option (to install to $Config{installsitelib} and $Config{installsitebin})
|   - run me with --local-lib option e.g. cpanm --local-lib=~/perl5
!   - Set PERL_CPANM_OPT="--local-lib=~/perl5" environment variable (in your shell rc file)
!   - Configure local::lib in your shell to set PERL_MM_OPT etc.
!
DIAG
    sleep 2;
}

sub _core_only_inc {
    my($self, $base) = @_;
    require local::lib;
    (
        local::lib->install_base_perl_path($base),
        local::lib->install_base_arch_path($base),
        @Config{qw(privlibexp archlibexp)},
    );
}

sub _diff {
    my($self, $old, $new) = @_;

    my @diff;
    my %old = map { $_ => 1 } @$old;
    for my $n (@$new) {
        push @diff, $n unless exists $old{$n};
    }

    @diff;
}

sub _setup_local_lib_env {
    my($self, $base) = @_;
    local $SIG{__WARN__} = sub { }; # catch 'Attempting to write ...'
    local::lib->setup_env_hash_for($base);
}

sub setup_local_lib {
    my($self, $base) = @_;
    $base = undef if $base eq '_';

    require local::lib;
    {
        local $0 = 'cpanm'; # so curl/wget | perl works
        $base ||= "~/perl5";
        if ($self->{self_contained}) {
            my @inc = $self->_core_only_inc($base);
            $self->{search_inc} = [ @inc ];
        } else {
            $self->{search_inc} = [
                local::lib->install_base_arch_path($base),
                local::lib->install_base_perl_path($base),
                @INC,
            ];
        }
        $self->_setup_local_lib_env($base);
    }

    $self->bootstrap_local_lib_deps;
}

sub bootstrap_local_lib_deps {
    my $self = shift;
    push @{$self->{bootstrap_deps}},
        'ExtUtils::MakeMaker' => 6.31,
        'ExtUtils::Install'   => 1.46;
}

sub prompt_bool {
    my($self, $mess, $def) = @_;

    my $val = $self->prompt($mess, $def);
    return lc $val eq 'y';
}

sub prompt {
    my($self, $mess, $def) = @_;

    my $isa_tty = -t STDIN && (-t STDOUT || !(-f STDOUT || -c STDOUT)) ;
    my $dispdef = defined $def ? "[$def] " : " ";
    $def = defined $def ? $def : "";

    if (!$self->{prompt} || (!$isa_tty && eof STDIN)) {
        return $def;
    }

    local $|=1;
    local $\;
    my $ans;
    eval {
        local $SIG{ALRM} = sub { undef $ans; die "alarm\n" };
        print STDOUT "$mess $dispdef";
        alarm $self->{prompt_timeout} if $self->{prompt_timeout};
        $ans = <STDIN>;
        alarm 0;
    };
    if ( defined $ans ) {
        chomp $ans;
    } else { # user hit ctrl-D or alarm timeout
        print STDOUT "\n";
    }

    return (!defined $ans || $ans eq '') ? $def : $ans;
}

sub diag_ok {
    my($self, $msg) = @_;
    chomp $msg;
    $msg ||= "OK";
    if ($self->{in_progress}) {
        $self->_diag("$msg\n");
        $self->{in_progress} = 0;
    }
    $self->log("-> $msg\n");
}

sub diag_fail {
    my($self, $msg, $always) = @_;
    chomp $msg;
    if ($self->{in_progress}) {
        $self->_diag("FAIL\n");
        $self->{in_progress} = 0;
    }

    if ($msg) {
        $self->_diag("! $msg\n", $always);
        $self->log("-> FAIL $msg\n");
    }
}

sub diag_progress {
    my($self, $msg) = @_;
    chomp $msg;
    $self->{in_progress} = 1;
    $self->_diag("$msg ... ");
    $self->log("$msg\n");
}

sub _diag {
    my($self, $msg, $always) = @_;
    print STDERR $msg if $always or $self->{verbose} or !$self->{quiet};
}

sub diag {
    my($self, $msg, $always) = @_;
    $self->_diag($msg, $always);
    $self->log($msg);
}

sub chat {
    my $self = shift;
    print STDERR @_ if $self->{verbose};
    $self->log(@_);
}

sub log {
    my $self = shift;
    open my $out, ">>$self->{log}";
    print $out @_;
}

sub run {
    my($self, $cmd) = @_;

    if (WIN32 && ref $cmd eq 'ARRAY') {
        $cmd = join q{ }, map { $self->shell_quote($_) } @$cmd;
    }

    if (ref $cmd eq 'ARRAY') {
        my $pid = fork;
        if ($pid) {
            waitpid $pid, 0;
            return !$?;
        } else {
            $self->run_exec($cmd);
        }
    } else {
        unless ($self->{verbose}) {
            $cmd .= " >> " . $self->shell_quote($self->{log}) . " 2>&1";
        }
        !system $cmd;
    }
}

sub run_exec {
    my($self, $cmd) = @_;

    if (ref $cmd eq 'ARRAY') {
        unless ($self->{verbose}) {
            open my $logfh, ">>", $self->{log};
            open STDERR, '>&', $logfh;
            open STDOUT, '>&', $logfh;
            close $logfh;
        }
        exec @$cmd;
    } else {
        unless ($self->{verbose}) {
            $cmd .= " >> " . $self->shell_quote($self->{log}) . " 2>&1";
        }
        exec $cmd;
    }
}

sub run_timeout {
    my($self, $cmd, $timeout) = @_;
    return $self->run($cmd) if WIN32 || $self->{verbose} || !$timeout;

    my $pid = fork;
    if ($pid) {
        eval {
            local $SIG{ALRM} = sub { die "alarm\n" };
            alarm $timeout;
            waitpid $pid, 0;
            alarm 0;
        };
        if ($@ && $@ eq "alarm\n") {
            $self->diag_fail("Timed out (> ${timeout}s). Use --verbose to retry.");
            local $SIG{TERM} = 'IGNORE';
            kill TERM => 0;
            waitpid $pid, 0;
            return;
        }
        return !$?;
    } elsif ($pid == 0) {
        $self->run_exec($cmd);
    } else {
        $self->chat("! fork failed: falling back to system()\n");
        $self->run($cmd);
    }
}

sub configure {
    my($self, $cmd) = @_;

    # trick AutoInstall
    local $ENV{PERL5_CPAN_IS_RUNNING} = local $ENV{PERL5_CPANPLUS_IS_RUNNING} = $$;

    # e.g. skip CPAN configuration on local::lib
    local $ENV{PERL5_CPANM_IS_RUNNING} = $$;

    my $use_default = !$self->{interactive};
    local $ENV{PERL_MM_USE_DEFAULT} = $use_default;

    # skip man page generation
    local $ENV{PERL_MM_OPT} = $ENV{PERL_MM_OPT};
    unless ($self->{pod2man}) {
        $ENV{PERL_MM_OPT} .= " INSTALLMAN1DIR=none INSTALLMAN3DIR=none";
    }

    local $self->{verbose} = $self->{verbose} || $self->{interactive};
    $self->run_timeout($cmd, $self->{configure_timeout});
}

sub build {
    my($self, $cmd, $distname) = @_;

    return 1 if $self->run_timeout($cmd, $self->{build_timeout});
    while (1) {
        my $ans = lc $self->prompt("Building $distname failed.\nYou can s)kip, r)etry or l)ook ?", "s");
        return                               if $ans eq 's';
        return $self->build($cmd, $distname) if $ans eq 'r';
        $self->look                          if $ans eq 'l';
    }
}

sub test {
    my($self, $cmd, $distname) = @_;
    return 1 if $self->{notest};

    # http://www.nntp.perl.org/group/perl.perl5.porters/2009/10/msg152656.html
    local $ENV{AUTOMATED_TESTING} = 1
        unless $self->env('NO_AUTOMATED_TESTING');

    return 1 if $self->run_timeout($cmd, $self->{test_timeout});
    if ($self->{force}) {
        $self->diag_fail("Testing $distname failed but installing it anyway.");
        return 1;
    } else {
        $self->diag_fail;
        while (1) {
            my $ans = lc $self->prompt("Testing $distname failed.\nYou can s)kip, r)etry, f)orce install or l)ook ?", "s");
            return                              if $ans eq 's';
            return $self->test($cmd, $distname) if $ans eq 'r';
            return 1                            if $ans eq 'f';
            $self->look                         if $ans eq 'l';
        }
    }
}

sub install {
    my($self, $cmd, $uninst_opts) = @_;

    if ($self->{sudo}) {
        unshift @$cmd, "sudo";
    }

    if ($self->{uninstall_shadows} && !$ENV{PERL_MM_OPT}) {
        push @$cmd, @$uninst_opts;
    }

    $self->run($cmd);
}

sub look {
    my $self = shift;

    my $shell = $ENV{SHELL};
    $shell  ||= $ENV{COMSPEC} if WIN32;
    if ($shell) {
        my $cwd = Cwd::cwd;
        $self->diag("Entering $cwd with $shell\n");
        system $shell;
    } else {
        $self->diag_fail("You don't seem to have a SHELL :/");
    }
}

sub chdir {
    my $self = shift;
    Cwd::chdir(File::Spec->canonpath($_[0])) or die "$_[0]: $!";
}

sub configure_mirrors {
    my $self = shift;
    unless (@{$self->{mirrors}}) {
        $self->{mirrors} = [ 'http://search.cpan.org/CPAN' ];
    }
    for (@{$self->{mirrors}}) {
        s!^/!file:///!;
        s!/$!!;
    }
}

sub self_upgrade {
    my $self = shift;
    $self->{argv} = [ 'App::cpanminus' ];
    return; # continue
}

sub install_module {
    my($self, $module, $depth, $version) = @_;

    if ($self->{seen}{$module}++) {
        $self->chat("Already tried $module. Skipping.\n");
        return 1;
    }

    my $dist = $self->resolve_name($module, $version);
    unless ($dist) {
        $self->diag_fail("Couldn't find module or a distribution $module ($version)", 1);
        return;
    }

    if ($dist->{distvname} && $self->{seen}{$dist->{distvname}}++) {
        $self->chat("Already tried $dist->{distvname}. Skipping.\n");
        return 1;
    }

    if ($self->{cmd} eq 'info') {
        print $self->format_dist($dist), "\n";
        return 1;
    }

    $self->check_libs;
    $self->setup_module_build_patch unless $self->{pod2man};

    if ($dist->{module}) {
        my($ok, $local) = $self->check_module($dist->{module}, $dist->{module_version} || 0);
        if ($self->{skip_installed} && $ok) {
            $self->diag("$dist->{module} is up to date. ($local)\n", 1);
            return 1;
        }
    }

    if ($dist->{dist} eq 'perl'){
        $self->diag("skipping $dist->{pathname}\n");
        return 1;
    }

    $self->diag("--> Working on $module\n");

    $dist->{dir} ||= $self->fetch_module($dist);

    unless ($dist->{dir}) {
        $self->diag_fail("Failed to fetch distribution $dist->{distvname}", 1);
        return;
    }

    $self->chat("Entering $dist->{dir}\n");
    $self->chdir($self->{base});
    $self->chdir($dist->{dir});

    if ($self->{cmd} eq 'look') {
        $self->look;
        return 1;
    }

    return $self->build_stuff($module, $dist, $depth);
}

sub format_dist {
    my($self, $dist) = @_;

    # TODO support --dist-format?
    return "$dist->{cpanid}/$dist->{filename}";
}

sub fetch_module {
    my($self, $dist) = @_;

    $self->chdir($self->{base});

    for my $uri (@{$dist->{uris}}) {
        $self->diag_progress("Fetching $uri");

        # Ugh, $dist->{filename} can contain sub directory
        my $filename = $dist->{filename} || $uri;
        my $name = File::Basename::basename($filename);

        my $cancelled;
        my $fetch = sub {
            my $file;
            eval {
                local $SIG{INT} = sub { $cancelled = 1; die "SIGINT\n" };
                $self->mirror($uri, $name);
                $file = $name if -e $name;
            };
            $self->chat("$@") if $@ && $@ ne "SIGINT\n";
            return $file;
        };

        my($try, $file);
        while ($try++ < 3) {
            $file = $fetch->();
            last if $cancelled or $file;
            $self->diag_fail("Download $uri failed. Retrying ... ");
        }

        if ($cancelled) {
            $self->diag_fail("Download cancelled.");
            return;
        }

        unless ($file) {
            $self->diag_fail("Failed to download $uri");
            next;
        }

        $self->diag_ok;
        $dist->{local_path} = File::Spec->rel2abs($name);

        my $dir = $self->unpack($file);
        next unless $dir; # unpack failed

        if (my $save = $self->{save_dists}) {
            my $path = "$save/authors/id/$dist->{pathname}";
            $self->chat("Copying $name to $path\n");
            File::Path::mkpath([ File::Basename::dirname($path) ], 0, 0777);
            File::Copy::copy($file, $path) or warn $!;
        }

        return $dist, $dir;
    }
}

sub unpack {
    my($self, $file) = @_;
    $self->chat("Unpacking $file\n");
    my $dir = $file =~ /\.zip/i ? $self->unzip($file) : $self->untar($file);
    unless ($dir) {
        $self->diag_fail("Failed to unpack $file: no directory");
    }
    return $dir;
}

sub resolve_name {
    my($self, $module, $version) = @_;

    # URL
    if ($module =~ /^(ftp|https?|file):/) {
        if ($module =~ m!authors/id/!) {
            return $self->cpan_dist($module, $module);
        } else {
            return { uris => [ $module ] };
        }
    }

    # Directory
    if ($module =~ m!^[\./]! && -d $module) {
        return {
            source => 'local',
            dir => Cwd::abs_path($module),
        };
    }

    # File
    if (-f $module) {
        return {
            source => 'local',
            uris => [ "file://" . Cwd::abs_path($module) ],
        };
    }

    # cpan URI
    if ($module =~ s!^cpan:///distfile/!!) {
        return $self->cpan_dist($module);
    }

    # PAUSEID/foo
    if ($module =~ m!([A-Z]{3,})/!) {
        return $self->cpan_dist($module);
    }

    # Module name
    return $self->search_module($module, $version);
}

sub cpan_module {
    my($self, $module, $dist, $version) = @_;

    my $dist = $self->cpan_dist($dist);
    $dist->{module} = $module;
    $dist->{module_version} = $version if $version && $version ne 'undef';

    return $dist;
}

sub cpan_dist {
    my($self, $dist, $url) = @_;

    $dist =~ s!^([A-Z]{3})!substr($1,0,1)."/".substr($1,0,2)."/".$1!e;

    require CPAN::DistnameInfo;
    my $d = CPAN::DistnameInfo->new($dist);

    if ($url) {
        $url = [ $url ] unless ref $url eq 'ARRAY';
    } else {
        my $id = $d->cpanid;
        my $fn = substr($id, 0, 1) . "/" . substr($id, 0, 2) . "/" . $id . "/" . $d->filename;

        my @mirrors = @{$self->{mirrors}};
        my @urls    = map "$_/authors/id/$fn", @mirrors;

        $url = \@urls,
    }

    return {
        $d->properties,
        source  => 'cpan',
        uris    => $url,
    };
}

sub setup_module_build_patch {
    my $self = shift;

    open my $out, ">$self->{base}/ModuleBuildSkipMan.pm" or die $!;
    print $out <<EOF;
package ModuleBuildSkipMan;
CHECK {
  if (%Module::Build::) {
    no warnings 'redefine';
    *Module::Build::Base::ACTION_manpages = sub {};
    *Module::Build::Base::ACTION_docs     = sub {};
  }
}
1;
EOF
}

sub check_module {
    my($self, $mod, $want_ver) = @_;

    require Module::Metadata;
    my $meta = Module::Metadata->new_from_module($mod, inc => $self->{search_inc})
        or return 0, undef;

    my $version = $meta->version;

    # When -L is in use, the version loaded from 'perl' library path
    # might be newer than (or actually wasn't core at) the version
    # that is shipped with the current perl
    if ($self->{self_contained} && $self->loaded_from_perl_lib($meta)) {
        require Module::CoreList;
        unless (exists $Module::CoreList::version{$]+0}{$mod}) {
            return 0, undef;
        }
        $version = $Module::CoreList::version{$]+0}{$mod};
    }

    $self->{local_versions}{$mod} = $version;

    if ($self->is_deprecated($meta)){
        return 0, $version;
    } elsif (!$want_ver or $version >= version->new($want_ver)) {
        return 1, ($version || 'undef');
    } else {
        return 0, $version;
    }
}

sub is_deprecated {
    my($self, $meta) = @_;

    my $deprecated = eval {
        require Module::CoreList;
        Module::CoreList::is_deprecated($meta->{module});
    };

    return unless $deprecated;
    return $self->loaded_from_perl_lib($meta);
}

sub loaded_from_perl_lib {
    my($self, $meta) = @_;

    require Config;
    for my $dir (qw(archlibexp privlibexp)) {
        my $confdir = $Config{$dir};
        if ($confdir eq substr($meta->filename, 0, length($confdir))) {
            return 1;
        }
    }

    return;
}

sub should_install {
    my($self, $mod, $ver) = @_;

    $self->chat("Checking if you have $mod $ver ... ");
    my($ok, $local) = $self->check_module($mod, $ver);

    if ($ok)       { $self->chat("Yes ($local)\n") }
    elsif ($local) { $self->chat("No ($local < $ver)\n") }
    else           { $self->chat("No\n") }

    return $mod unless $ok;
    return;
}

sub install_deps {
    my($self, $dir, $depth, @deps) = @_;

    my(@install, %seen);
    while (my($mod, $ver) = splice @deps, 0, 2) {
        next if $seen{$mod} or $mod eq 'perl' or $mod eq 'Config';
        if ($self->should_install($mod, $ver)) {
            push @install, [ $mod, $ver ];
            $seen{$mod} = 1;
        }
    }

    if (@install) {
        $self->diag("==> Found dependencies: " . join(", ",  map $_->[0], @install) . "\n");
    }

    my @fail;
    for my $mod (@install) {
        $self->install_module($mod->[0], $depth + 1, $mod->[1])
            or push @fail, $mod->[0];
    }

    $self->chdir($self->{base});
    $self->chdir($dir) if $dir;

    return @fail;
}

sub install_deps_bailout {
    my($self, $target, $dir, $depth, @deps) = @_;

    my @fail = $self->install_deps($dir, $depth, @deps);
    if (@fail) {
        unless ($self->prompt_bool("Installing the following dependencies failed:\n==> " .
                                   join(", ", @fail) . "\nDo you want to continue building $target anyway?", "n")) {
            $self->diag_fail("Bailing out the installation for $target. Retry with --prompt or --force.", 1);
            return;
        }
    }

    return 1;
}

sub build_stuff {
    my($self, $stuff, $dist, $depth) = @_;

    my @config_deps;
    if (!%{$dist->{meta} || {}} && -e 'META.yml') {
        $self->chat("Checking configure dependencies from META.yml\n");
        $dist->{meta} = $self->parse_meta('META.yml');
    }

    if (!$dist->{meta} && $dist->{source} eq 'cpan') {
        $self->chat("META.yml not found or unparsable. Fetching META.yml from search.cpan.org\n");
        $dist->{meta} = $self->fetch_meta_sco($dist);
    }

    $dist->{meta} ||= {};

    push @config_deps, %{$dist->{meta}{configure_requires} || {}};

    my $target = $dist->{meta}{name} ? "$dist->{meta}{name}-$dist->{meta}{version}" : $dist->{dir};

    $self->install_deps_bailout($target, $dist->{dir}, $depth, @config_deps)
        or return;

    $self->diag_progress("Configuring $target");

    my $configure_state = $self->configure_this($dist);

    $self->diag_ok($configure_state->{configured_ok} ? "OK" : "N/A");

    my @deps = $self->find_prereqs($dist);
    my $module_name = $self->find_module_name($configure_state) || $dist->{meta}{name};
    $module_name =~ s/-/::/g;

    if ($self->{showdeps}) {
        my %rootdeps = (@config_deps, @deps); # merge
        for my $mod (keys %rootdeps) {
            my $ver = $rootdeps{$mod};
            print $mod, ($ver ? "~$ver" : ""), "\n";
        }
        return 1;
    }

    my $distname = $dist->{meta}{name} ? "$dist->{meta}{name}-$dist->{meta}{version}" : $stuff;

    my $walkup;
    if ($self->{scandeps}) {
        $walkup = $self->scandeps_append_child($dist);
    }

    $self->install_deps_bailout($distname, $dist->{dir}, $depth, @deps)
        or return;

    if ($self->{scandeps}) {
        unless ($configure_state->{configured_ok}) {
            my $diag = <<DIAG;
! Configuring $distname failed. See $self->{log} for details.
! You might have to install the following modules first to get --scandeps working correctly.
DIAG
            if (@config_deps) {
                my @tree = @{$self->{scandeps_tree}};
                $diag .= "!\n" . join("", map "! * $_->[0]{module}\n", @tree[0..$#tree-1]) if @tree;
            }
            $self->diag("!\n$diag!\n", 1);
        }
        $walkup->();
        return 1;
    }

    if ($self->{installdeps} && $depth == 0) {
        if ($configure_state->{configured_ok}) {
            $self->diag("<== Installed dependencies for $stuff. Finishing.\n");
            return 1;
        } else {
            $self->diag("! Configuring $distname failed. See $self->{log} for details.\n", 1);
            return;
        }
    }

    my $installed;
    if ($configure_state->{use_module_build} && -e 'Build' && -f _) {
        my @switches = $self->{pod2man} ? () : ("-I$self->{base}", "-MModuleBuildSkipMan");
        $self->diag_progress("Building " . ($self->{notest} ? "" : "and testing ") . $distname);
        $self->build([ $self->{perl}, @switches, "./Build" ], $distname) &&
        $self->test([ $self->{perl}, "./Build", "test" ], $distname) &&
        $self->install([ $self->{perl}, @switches, "./Build", "install" ], [ "--uninst", 1 ]) &&
        $installed++;
    } elsif ($self->{make} && -e 'Makefile') {
        $self->diag_progress("Building " . ($self->{notest} ? "" : "and testing ") . $distname);
        $self->build([ $self->{make} ], $distname) &&
        $self->test([ $self->{make}, "test" ], $distname) &&
        $self->install([ $self->{make}, "install" ], [ "UNINST=1" ]) &&
        $installed++;
    } else {
        my $why;
        my $configure_failed = $configure_state->{configured} && !$configure_state->{configured_ok};
        if ($configure_failed) { $why = "Configure failed for $distname." }
        elsif ($self->{make})  { $why = "The distribution doesn't have a proper Makefile.PL/Build.PL" }
        else                   { $why = "Can't configure the distribution. You probably need to have 'make'." }

        $self->diag_fail("$why See $self->{log} for details.", 1);
        return;
    }

    if ($installed) {
        my $local   = $self->{local_versions}{$dist->{module} || ''};
        my $version = $dist->{module_version} || $dist->{meta}{version} || $dist->{version};
        my $reinstall = $local && ($local eq $version);

        my $how = $reinstall ? "reinstalled $distname"
                : $local     ? "installed $distname (upgraded from $local)"
                             : "installed $distname" ;
        my $msg = "Successfully $how";
        $self->diag_ok;
        $self->diag("$msg\n", 1);
        $self->{installed_dists}++;
        $self->save_meta($stuff, $dist, $module_name, \@config_deps, \@deps);
        return 1;
    } else {
        my $msg = "Building $distname failed";
        $self->diag_fail("Installing $stuff failed. See $self->{log} for details.", 1);
        return;
    }
}

sub configure_this {
    my($self, $dist) = @_;

    if ($self->{skip_configure}) {
        my $eumm = -e 'Makefile';
        my $mb   = -e 'Build' && -f _;
        return {
            configured => 1,
            configured_ok => $eumm || $mb,
            use_module_build => $mb,
        };
    }

    my @mb_switches;
    unless ($self->{pod2man}) {
        # it has to be push, so Module::Build is loaded from the adjusted path when -L is in use
        push @mb_switches, ("-I$self->{base}", "-MModuleBuildSkipMan");
    }

    my $state = {};

    my $try_eumm = sub {
        if (-e 'Makefile.PL') {
            $self->chat("Running Makefile.PL\n");

            # NOTE: according to Devel::CheckLib, most XS modules exit
            # with 0 even if header files are missing, to avoid receiving
            # tons of FAIL reports in such cases. So exit code can't be
            # trusted if it went well.
            if ($self->configure([ $self->{perl}, "Makefile.PL" ])) {
                $state->{configured_ok} = -e 'Makefile';
            }
            $state->{configured}++;
        }
    };

    my $try_mb = sub {
        if (-e 'Build.PL') {
            $self->chat("Running Build.PL\n");
            if ($self->configure([ $self->{perl}, @mb_switches, "Build.PL" ])) {
                $state->{configured_ok} = -e 'Build' && -f _;
            }
            $state->{use_module_build}++;
            $state->{configured}++;
        }
    };

    # Module::Build deps should use MakeMaker because that causes circular deps and fail
    # Otherwise we should prefer Build.PL
    my %should_use_mm = map { $_ => 1 } qw( version ExtUtils-ParseXS ExtUtils-Install ExtUtils-Manifest );

    my @try;
    if ($dist->{dist} && $should_use_mm{$dist->{dist}}) {
        @try = ($try_eumm, $try_mb);
    } else {
        @try = ($try_mb, $try_eumm);
    }

    for my $try (@try) {
        $try->();
        last if $state->{configured_ok};
    }

    unless ($state->{configured_ok}) {
        while (1) {
            my $ans = lc $self->prompt("Configuring $dist->{dist} failed.\nYou can s)kip, r)etry or l)ook ?", "s");
            last                                if $ans eq 's';
            return $self->configure_this($dist) if $ans eq 'r';
            $self->look                         if $ans eq 'l';
        }
    }

    return $state;
}

sub find_module_name {
    my($self, $state) = @_;

    return unless $state->{configured_ok};

    if ($state->{use_module_build} &&
        -e "_build/build_params") {
        my $params = do { open my $in, "_build/build_params"; $self->safe_eval(join "", <$in>) };
        return eval { $params->[2]{module_name} } || undef;
    } elsif (-e "Makefile") {
        open my $mf, "Makefile";
        while (<$mf>) {
            if (/^\#\s+NAME\s+=>\s+(.*)/) {
                return $self->safe_eval($1);
            }
        }
    }

    return;
}

sub save_meta {
    my($self, $module, $dist, $module_name, $config_deps, $build_deps) = @_;

    return unless $dist->{distvname} && $dist->{source} eq 'cpan';

    my $base = ($ENV{PERL_MM_OPT} || '') =~ /INSTALL_BASE=/
        ? ($self->install_base($ENV{PERL_MM_OPT}) . "/lib/perl5") : $Config{sitelibexp};

    my $provides = $self->_merge_hashref(
        map Module::Metadata->package_versions_from_directory($_),
            qw( blib/lib blib/arch ) # FCGI.pm :(
    );

    mkdir "blib/meta", 0777 or die $!;

    my $local = {
        name => $module_name,
        module => $module,
        version => $provides->{$module}{version} || $dist->{version},
        dist => $dist->{distvname},
        pathname => $dist->{pathname},
        provides => $provides,
    };

    require JSON::PP;
    open my $fh, ">", "blib/meta/install.json" or die $!;
    print $fh JSON::PP::encode_json($local);

    # Existence of MYMETA.* Depends on EUMM/M::B versions and CPAN::Meta
    if (-e "MYMETA.json") {
        File::Copy::copy("MYMETA.json", "blib/meta/MYMETA.json");
    }

    my @cmd = (
        ($self->{sudo} ? 'sudo' : ()),
        $^X,
        '-MExtUtils::Install=install',
        '-e',
        qq[install({ 'blib/meta' => "$base/$Config{archname}/.meta/$dist->{distvname}" })],
    );
    $self->run(\@cmd);
}

sub _merge_hashref {
    my($self, @hashrefs) = @_;

    my %hash;
    for my $h (@hashrefs) {
        %hash = (%hash, %$h);
    }

    return \%hash;
}

sub install_base {
    my($self, $mm_opt) = @_;
    $mm_opt =~ /INSTALL_BASE=(\S+)/ and return $1;
    die "Your PERL_MM_OPT doesn't contain INSTALL_BASE";
}

sub safe_eval {
    my($self, $code) = @_;
    eval $code;
}

sub find_prereqs {
    my($self, $dist) = @_;

    my @deps = $self->extract_meta_prereqs($dist);

    if ($dist->{module} =~ /^Bundle::/i) {
        push @deps, $self->bundle_deps($dist);
    }

    return @deps;
}

sub extract_meta_prereqs {
    my($self, $dist) = @_;

    my $meta = $dist->{meta};

    my @deps;
    if (-e "MYMETA.json") {
        require JSON::PP;
        $self->chat("Checking dependencies from MYMETA.json ...\n");
        my $json = do { open my $in, "<MYMETA.json"; local $/; <$in> };
        my $mymeta = JSON::PP::decode_json($json);
        if ($mymeta) {
            $meta->{$_} = $mymeta->{$_} for qw(name version);
            return $self->extract_requires($mymeta);
        }
    }

    if (-e 'MYMETA.yml') {
        $self->chat("Checking dependencies from MYMETA.yml ...\n");
        my $mymeta = $self->parse_meta('MYMETA.yml');
        if ($mymeta) {
            $meta->{$_} = $mymeta->{$_} for qw(name version);
            return $self->extract_requires($mymeta);
        }
    }

    if (-e '_build/prereqs') {
        $self->chat("Checking dependencies from _build/prereqs ...\n");
        my $mymeta = do { open my $in, "_build/prereqs"; $self->safe_eval(join "", <$in>) };
        @deps = $self->extract_requires($mymeta);
    } elsif (-e 'Makefile') {
        $self->chat("Finding PREREQ from Makefile ...\n");
        open my $mf, "Makefile";
        while (<$mf>) {
            if (/^\#\s+PREREQ_PM => {\s*(.*?)\s*}/) {
                my @all;
                my @pairs = split ', ', $1;
                for (@pairs) {
                    my ($pkg, $v) = split '=>', $_;
                    push @all, [ $pkg, $v ];
                }
                my $list = join ", ", map { "'$_->[0]' => $_->[1]" } @all;
                my $prereq = $self->safe_eval("no strict; +{ $list }");
                push @deps, %$prereq if $prereq;
                last;
            }
        }
    }

    return @deps;
}

sub bundle_deps {
    my($self, $dist) = @_;

    my @files;
    File::Find::find({
        wanted => sub { push @files, File::Spec->rel2abs($_) if /\.pm/i },
        no_chdir => 1,
    }, '.');

    my @deps;

    for my $file (@files) {
        open my $pod, "<", $file or next;
        my $in_contents;
        while (<$pod>) {
            if (/^=head\d\s+CONTENTS/) {
                $in_contents = 1;
            } elsif (/^=/) {
                $in_contents = 0;
            } elsif ($in_contents) {
                /^(\S+)\s*(\S+)?/
                    and push @deps, $1, $self->maybe_version($2);
            }
        }
    }

    return @deps;
}

sub maybe_version {
    my($self, $string) = @_;
    return $string && $string =~ /^\.?\d/ ? $string : undef;
}

sub extract_requires {
    my($self, $meta) = @_;

    if ($meta->{'meta-spec'} && $meta->{'meta-spec'}{version} == 2) {
        my @phase = $self->{notest} ? qw( build runtime ) : qw( build test runtime );
        my @deps = map {
            my $p = $meta->{prereqs}{$_} || {};
            %{$p->{requires} || {}};
        } @phase;
        return @deps;
    }

    my @deps;
    push @deps, %{$meta->{build_requires}} if $meta->{build_requires};
    push @deps, %{$meta->{requires}} if $meta->{requires};

    return @deps;
}

sub cleanup_workdirs {
    my $self = shift;

    my $expire = time - 24 * 60 * 60 * $self->{auto_cleanup};
    my @targets;

    opendir my $dh, "$self->{home}/work";
    while (my $e = readdir $dh) {
        next if $e !~ /^(\d+)\.\d+$/; # {UNIX time}.{PID}
        my $time = $1;
        if ($time < $expire) {
            push @targets, "$self->{home}/work/$e";
        }
    }

    if (@targets) {
        $self->chat("Expiring ", scalar(@targets), " work directories.\n");
        File::Path::rmtree(\@targets, 0, 0); # safe = 0, since blib usually doesn't have write bits
    }
}

sub scandeps_append_child {
    my($self, $dist) = @_;

    my $new_node = [ $dist, [] ];

    my $curr_node = $self->{scandeps_current} || [ undef, $self->{scandeps_tree} ];
    push @{$curr_node->[1]}, $new_node;

    $self->{scandeps_current} = $new_node;

    return sub { $self->{scandeps_current} = $curr_node };
}

sub dump_scandeps {
    my $self = shift;

    if ($self->{format} eq 'tree') {
        $self->walk_down(sub {
            my($dist, $depth) = @_;
            if ($depth == 0) {
                print "$dist->{distvname}\n";
            } else {
                print " " x ($depth - 1);
                print "\\_ $dist->{distvname}\n";
            }
        }, 1);
    } elsif ($self->{format} =~ /^dists?$/) {
        $self->walk_down(sub {
            my($dist, $depth) = @_;
            print $self->format_dist($dist), "\n";
        }, 0);
    } elsif ($self->{format} eq 'json') {
        require JSON::PP;
        print JSON::PP::encode_json($self->{scandeps_tree});
    } elsif ($self->{format} eq 'yaml') {
        require YAML;
        print YAML::Dump($self->{scandeps_tree});
    } else {
        $self->diag("Unknown format: $self->{format}\n");
    }
}

sub walk_down {
    my($self, $cb, $pre) = @_;
    $self->_do_walk_down($self->{scandeps_tree}, $cb, 0, $pre);
}

sub _do_walk_down {
    my($self, $children, $cb, $depth, $pre) = @_;

    # DFS - $pre determines when we call the callback
    for my $node (@$children) {
        $cb->($node->[0], $depth) if $pre;
        $self->_do_walk_down($node->[1], $cb, $depth + 1, $pre);
        $cb->($node->[0], $depth) unless $pre;
    }
}

sub DESTROY {
    my $self = shift;
    $self->{at_exit}->($self) if $self->{at_exit};
}

# Utils

sub shell_quote {
    my($self, $stuff) = @_;
    $stuff =~ /^${quote}.+${quote}$/ ? $stuff : ($quote . $stuff . $quote);
}

sub which {
    my($self, $name) = @_;
    my $exe_ext = $Config{_exe};
    for my $dir (File::Spec->path) {
        my $fullpath = File::Spec->catfile($dir, $name);
        if (-x $fullpath || -x ($fullpath .= $exe_ext)) {
            if ($fullpath =~ /\s/ && $fullpath !~ /^$quote/) {
                $fullpath = $self->shell_quote($fullpath);
            }
            return $fullpath;
        }
    }
    return;
}

sub get      { $_[0]->{_backends}{get}->(@_) };
sub mirror   { $_[0]->{_backends}{mirror}->(@_) };
sub untar    { $_[0]->{_backends}{untar}->(@_) };
sub unzip    { $_[0]->{_backends}{unzip}->(@_) };

sub file_get {
    my($self, $uri) = @_;
    open my $fh, "<$uri" or return;
    join '', <$fh>;
}

sub file_mirror {
    my($self, $uri, $path) = @_;
    File::Copy::copy($uri, $path);
}

sub init_tools {
    my $self = shift;

    return if $self->{initialized}++;

    if ($self->{make} = $self->which($Config{make})) {
        $self->chat("You have make $self->{make}\n");
    }

    # use --no-lwp if they have a broken LWP, to upgrade LWP
    if ($self->{try_lwp} && eval { require LWP::UserAgent; LWP::UserAgent->VERSION(5.802) }) {
        $self->chat("You have LWP $LWP::VERSION\n");
        my $ua = sub {
            LWP::UserAgent->new(
                parse_head => 0,
                env_proxy => 1,
                agent => "cpanminus/$VERSION",
                timeout => 30,
                @_,
            );
        };
        $self->{_backends}{get} = sub {
            my $self = shift;
            my $res = $ua->()->request(HTTP::Request->new(GET => $_[0]));
            return unless $res->is_success;
            return $res->decoded_content;
        };
        $self->{_backends}{mirror} = sub {
            my $self = shift;
            my $res = $ua->()->mirror(@_);
            $res->code;
        };
    } elsif ($self->{try_wget} and my $wget = $self->which('wget')) {
        $self->chat("You have $wget\n");
        $self->{_backends}{get} = sub {
            my($self, $uri) = @_;
            return $self->file_get($uri) if $uri =~ s!^file:/+!/!;
            $self->safeexec( my $fh, $wget, $uri, ( $self->{verbose} ? () : '-q' ), '-O', '-' ) or die "wget $uri: $!";
            local $/;
            <$fh>;
        };
        $self->{_backends}{mirror} = sub {
            my($self, $uri, $path) = @_;
            return $self->file_mirror($uri, $path) if $uri =~ s!^file:/+!/!;
            $self->safeexec( my $fh, $wget, '--retry-connrefused', $uri, ( $self->{verbose} ? () : '-q' ), '-O', $path ) or die "wget $uri: $!";
            local $/;
            <$fh>;
        };
    } elsif ($self->{try_curl} and my $curl = $self->which('curl')) {
        $self->chat("You have $curl\n");
        $self->{_backends}{get} = sub {
            my($self, $uri) = @_;
            return $self->file_get($uri) if $uri =~ s!^file:/+!/!;
            $self->safeexec( my $fh, $curl, '-L', ( $self->{verbose} ? () : '-s' ), $uri ) or die "curl $uri: $!";
            local $/;
            <$fh>;
        };
        $self->{_backends}{mirror} = sub {
            my($self, $uri, $path) = @_;
            return $self->file_mirror($uri, $path) if $uri =~ s!^file:/+!/!;
            $self->safeexec( my $fh, $curl, '-L', $uri, ( $self->{verbose} ? () : '-s' ), '-#', '-o', $path ) or die "curl $uri: $!";
            local $/;
            <$fh>;
        };
    } else {
        require HTTP::Tiny;
        $self->chat("Falling back to HTTP::Tiny $HTTP::Tiny::VERSION\n");

        $self->{_backends}{get} = sub {
            my $self = shift;
            my $res = HTTP::Tiny->new->get($_[0]);
            return unless $res->{success};
            return $res->{content};
        };
        $self->{_backends}{mirror} = sub {
            my $self = shift;
            my $res = HTTP::Tiny->new->mirror(@_);
            return $res->{status};
        };
    }

    my $tar = $self->which('tar');
    my $tar_ver;
    my $maybe_bad_tar = sub { WIN32 || SUNOS || (($tar_ver = `$tar --version 2>/dev/null`) =~ /GNU.*1\.13/i) };

    if ($tar && !$maybe_bad_tar->()) {
        chomp $tar_ver;
        $self->chat("You have $tar: $tar_ver\n");
        $self->{_backends}{untar} = sub {
            my($self, $tarfile) = @_;

            my $xf = "xf" . ($self->{verbose} ? 'v' : '');
            my $ar = $tarfile =~ /bz2$/ ? 'j' : 'z';

            my($root, @others) = `$tar tf$ar $tarfile`
                or return undef;

            chomp $root;
            $root =~ s!^\./!!;
            $root =~ s{^(.+?)/.*$}{$1};

            system "$tar $xf$ar $tarfile";
            return $root if -d $root;

            $self->diag_fail("Bad archive: $tarfile");
            return undef;
        }
    } elsif (    $tar
             and my $gzip = $self->which('gzip')
             and my $bzip2 = $self->which('bzip2')) {
        $self->chat("You have $tar, $gzip and $bzip2\n");
        $self->{_backends}{untar} = sub {
            my($self, $tarfile) = @_;

            my $x  = "x" . ($self->{verbose} ? 'v' : '') . "f -";
            my $ar = $tarfile =~ /bz2$/ ? $bzip2 : $gzip;

            my($root, @others) = `$ar -dc $tarfile | $tar tf -`
                or return undef;

            chomp $root;
            $root =~ s{^(.+?)/.*$}{$1};

            system "$ar -dc $tarfile | $tar $x";
            return $root if -d $root;

            $self->diag_fail("Bad archive: $tarfile");
            return undef;
        }
    } elsif (eval { require Archive::Tar }) { # uses too much memory!
        $self->chat("Falling back to Archive::Tar $Archive::Tar::VERSION\n");
        $self->{_backends}{untar} = sub {
            my $self = shift;
            my $t = Archive::Tar->new($_[0]);
            my $root = ($t->list_files)[0];
            $root =~ s{^(.+?)/.*$}{$1};
            $t->extract;
            return -d $root ? $root : undef;
        };
    } else {
        $self->{_backends}{untar} = sub {
            die "Failed to extract $_[1] - You need to have tar or Archive::Tar installed.\n";
        };
    }

    if (my $unzip = $self->which('unzip')) {
        $self->chat("You have $unzip\n");
        $self->{_backends}{unzip} = sub {
            my($self, $zipfile) = @_;

            my $opt = $self->{verbose} ? '' : '-q';
            my(undef, $root, @others) = `$unzip -t $zipfile`
                or return undef;

            chomp $root;
            $root =~ s{^\s+testing:\s+(.+?)/\s+OK$}{$1};

            system "$unzip $opt $zipfile";
            return $root if -d $root;

            $self->diag_fail("Bad archive: [$root] $zipfile");
            return undef;
        }
    } else {
        $self->{_backends}{unzip} = sub {
            eval { require Archive::Zip }
                or  die "Failed to extract $_[1] - You need to have unzip or Archive::Zip installed.\n";
            my($self, $file) = @_;
            my $zip = Archive::Zip->new();
            my $status;
            $status = $zip->read($file);
            $self->diag_fail("Read of file[$file] failed")
                if $status != Archive::Zip::AZ_OK();
            my @members = $zip->members();
            my $root;
            for my $member ( @members ) {
                my $af = $member->fileName();
                next if ($af =~ m!^(/|\.\./)!);
                $root = $af unless $root;
                $status = $member->extractToFileNamed( $af );
                $self->diag_fail("Extracting of file[$af] from zipfile[$file failed")
                    if $status != Archive::Zip::AZ_OK();
            }
            return -d $root ? $root : undef;
        };
    }
}

sub safeexec {
    my $self = shift;
    my $rdr = $_[0] ||= Symbol::gensym();

    if (WIN32) {
        my $cmd = join q{ }, map { $self->shell_quote($_) } @_[ 1 .. $#_ ];
        return open( $rdr, "$cmd |" );
    }

    if ( my $pid = open( $rdr, '-|' ) ) {
        return $pid;
    }
    elsif ( defined $pid ) {
        exec( @_[ 1 .. $#_ ] );
        exit 1;
    }
    else {
        return;
    }
}

sub parse_meta {
    my($self, $file) = @_;
    return eval { (Parse::CPAN::Meta::LoadFile($file))[0] } || undef;
}

sub parse_meta_string {
    my($self, $yaml) = @_;
    return eval { (Parse::CPAN::Meta::Load($yaml))[0] } || undef;
}

1;
