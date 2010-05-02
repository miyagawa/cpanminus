package App::cpanminus::script;
use strict;
use Config;
use Cwd ();
use File::Basename ();
use File::Path ();
use File::Spec ();
use File::Copy ();
use Getopt::Long ();
use Parse::CPAN::Meta;

use constant WIN32 => $^O eq 'MSWin32';
use constant SUNOS => $^O eq 'solaris';

our $VERSION = "1.0002";
$VERSION = eval $VERSION;

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
        perl => $^X,
        argv => [],
        local_lib => undef,
        self_contained => undef,
        prompt_timeout => 0,
        prompt => undef,
        configure_timeout => 60,
        try_lwp => 1,
        uninstall_shadows => 1,
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

    if ($0 ne '-' && !-t STDIN){ # e.g. $ cpanm < author/requires.cpanm
        push @ARGV, $self->load_argv_from_fh(\*STDIN);
    }

    Getopt::Long::Configure("bundling");
    Getopt::Long::GetOptions(
        'f|force!'  => \$self->{force},
        'n|notest!' => \$self->{notest},
        'S|sudo!'   => \$self->{sudo},
        'v|verbose' => sub { $self->{verbose} = $self->{interactive} = 1 },
        'q|quiet'   => \$self->{quiet},
        'h|help'    => sub { $self->{action} = 'show_help' },
        'V|version' => sub { $self->{action} = 'show_version' },
        'perl=s'    => \$self->{perl},
        'l|local-lib=s' => sub { $self->{local_lib} = $self->maybe_abs($_[1]) },
        'L|local-lib-contained=s' => sub { $self->{local_lib} = $self->maybe_abs($_[1]); $self->{self_contained} = 1 },
        'mirror=s@' => $self->{mirrors},
        'prompt!'   => \$self->{prompt},
        'installdeps' => \$self->{installdeps},
        'skip-installed!' => \$self->{skip_installed},
        'interactive!' => \$self->{interactive},
        'i|install' => sub { $self->{cmd} = 'install' },
        'info'      => sub { $self->{cmd} = 'info' },
        'look'      => sub { $self->{cmd} = 'look' },
        'self-upgrade' => sub { $self->{cmd} = 'install'; $self->{skip_installed} = 1; push @ARGV, 'App::cpanminus' },
        'uninst-shadows!'  => \$self->{uninstall_shadows},
        'lwp!'    => \$self->{try_lwp},
    );

    $self->{argv} = \@ARGV;
}

sub check_libs {
    my $self = shift;
    return if $self->{_checked}++;

    $self->bootstrap_local_lib;
    if (@{$self->{bootstrap_deps} || []}) {
        local $self->{force} = 1; # to force install EUMM
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

    $self->show_help(1) unless @{$self->{argv}};

    $self->configure_mirrors;

    my @fail;
    for my $module (@{$self->{argv}}) {
        $self->install_module($module, 0)
            or push @fail, $module;
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

    open my $out, ">$self->{log}" or die "$self->{log}: $!";
    print $out "cpanm (App::cpanminus) $VERSION on perl $] built for $Config{archname}\n";
    print $out "Work directory is $self->{base}\n";
}

sub fetch_meta {
    my($self, $dist) = @_;

    my $meta_yml = $self->get("http://cpansearch.perl.org/src/$dist->{cpanid}/$dist->{distvname}/META.yml");
    return $self->parse_meta_string($meta_yml);
}

sub search_module {
    my($self, $module) = @_;

    $self->chat("Searching $module on cpanmetadb ...\n");
    my $uri  = "http://cpanmetadb.appspot.com/v1.0/package/$module";
    my $yaml = $self->get($uri);
    my $meta = $self->parse_meta_string($yaml);
    if ($meta->{distfile}) {
        return $self->cpan_module($module, $meta->{distfile}, $meta->{version});
    }

    $self->diag_fail("Finding $module on cpanmetadb failed.");

    $self->chat("Searching $module on search.cpan.org ...\n");
    my $uri  = "http://search.cpan.org/perldoc?$module";
    my $html = $self->get($uri);
    $html =~ m!<a href="/CPAN/authors/id/(.*?\.(?:tar\.gz|tgz|tar\.bz2|zip))">!
        and return $self->cpan_module($module, $1);

    $self->diag_fail("Finding $module on search.cpan.org failed.");

    return;
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
  -q,--quiet                Turns off all outpu
  --interactive             Turns on interactive configure (required for Task:: modules)
  -f,--force                force install
  -n,--notest               Do not run unit tests
  -S,--sudo                 sudo to run install commands
  --installdeps             Only install dependencies
  --skip-installed          Skip installation if you already have the latest version installed
  --mirror                  Specify the base URL for the mirror (e.g. http://cpan.cpantesters.org/)
  --prompt                  Prompt when build/test fails
  -l,--local-lib            Specify the install base to install modules
  -L,--local-lib-contained  Specify the install base to install all non-core modules

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

  export PERL_CPANM_OPT="--prompt --skip-installed -l ~/perl --mirror http://cpan.cpantesters.org"

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
    $lib =~ /^~/ ? $lib : Cwd::abs_path($lib);
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

sub _dump_inc {
    my($self, $inc) = @_;

    my @inc = map { qq('$_') } (@$inc, '.'); # . for inc/Module/Install.pm

    open my $out, ">$self->{base}/DumpedINC.pm" or die $!;
    local $" = ",";
    print $out "BEGIN { \@INC = (@inc) }\n1;\n";
}

sub _import_local_lib {
    my($self, @args) = @_;
    local $SIG{__WARN__} = sub { }; # catch 'Attempting to write ...'
    local::lib->import(@args);
}

sub setup_local_lib {
    my($self, $base) = @_;

    require local::lib;
    {
        local $0 = 'cpanm'; # so curl/wget | perl works
        $base ||= "~/perl5";
        if ($self->{self_contained}) {
            my @inc = $self->_core_only_inc($base);
            $self->_dump_inc(\@inc);
            $self->{search_inc} = [ @inc ];
        }
        $self->_import_local_lib($base);
    }

    $self->bootstrap_local_lib_deps;
}

sub bootstrap_local_lib_deps {
    my $self = shift;
    push @{$self->{bootstrap_deps}},
        'ExtUtils::MakeMaker' => 6.31,
        'ExtUtils::Install'   => 1.46,
        'Module::Build'       => 0.28; # TODO: 0.36 or later for MYMETA.yml once we do --bootstrap command
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

    if ($self->{quiet} || !$self->{prompt} || (!$isa_tty && eof STDIN)) {
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
    my($self, $msg) = @_;
    chomp $msg;
    if ($self->{in_progress}) {
        $self->_diag("FAIL\n");
        $self->{in_progress} = 0;
    }

    if ($msg) {
        $self->_diag("! $msg\n");
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
    my $self = shift;
    print STDERR @_ if $self->{verbose} or !$self->{quiet};
}

sub diag {
    my($self, $msg) = @_;
    $self->_diag($msg);
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
    local $ENV{PERL5_CPAN_IS_RUNNING} = $ENV{PERL5_CPANPLUS_IS_RUNNING} = $$;

    # e.g. skip CPAN configuration on local::lib
    local $ENV{PERL5_CPANM_IS_RUNNING} = $$;

    my $use_default = !$self->{interactive};
    local $ENV{PERL_MM_USE_DEFAULT} = $use_default;

    local $self->{verbose} = $self->{verbose} || $self->{interactive};
    $self->run_timeout($cmd, $self->{configure_timeout});
}

sub build {
    my($self, $cmd) = @_;
    $self->run_timeout($cmd, $self->{build_timeout});
}

sub test {
    my($self, $cmd, $distname) = @_;
    return 1 if $self->{notest};
    local $ENV{AUTOMATED_TESTING} = 1;

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

    if ($self->{uninstall_shadows}) {
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
    chdir(File::Spec->canonpath($_[0])) or die "$_[0]: $!";
}

sub configure_mirrors {
    my $self = shift;
    unless (@{$self->{mirrors}}) {
        $self->{mirrors} = [ 'http://search.cpan.org/CPAN' ];
    }
    for (@{$self->{mirrors}}) {
        s!/$!!;
    }
}

sub self_upgrade {
    my $self = shift;
    $self->{argv} = [ 'App::cpanminus' ];
    return; # continue
}

sub install_module {
    my($self, $module, $depth) = @_;

    if ($self->{seen}{$module}++) {
        $self->chat("Already tried $module. Skipping.\n");
        return 1;
    }

    my $dist = $self->resolve_name($module);
    unless ($dist) {
        $self->diag_fail("Couldn't find module or a distribution $module");
        return;
    }

    if ($dist->{distvname} && $self->{seen}{$dist->{distvname}}++) {
        $self->chat("Already tried $dist->{distvname}. Skipping.\n");
        return 1;
    }

    if ($dist->{source} eq 'cpan') {
        $dist->{meta} = $self->fetch_meta($dist);
    }

    if ($self->{cmd} eq 'info') {
        print $dist->{cpanid}, "/", $dist->{filename}, "\n";
        return 1;
    }

    if ($dist->{module}) {
        my($ok, $local) = $self->check_module($dist->{module}, $dist->{module_version} || 0);
        if ($self->{skip_installed} && $ok) {
            $self->diag("$dist->{module} is up to date. ($local)\n");
            return 1;
        }
    }

    $dist->{dir} ||= $self->fetch_module($dist);

    unless ($dist->{dir}) {
        $self->diag_fail("Failed to fetch distribution $dist->{distvname}");
        return;
    }

    $self->chat("Entering $dist->{dir}\n");
    $self->chdir($self->{base});
    $self->chdir($dist->{dir});

    if ($self->{cmd} eq 'look') {
        $self->look;
        return 1;
    }

    $self->check_libs;
    return $self->build_stuff($module, $dist, $depth);
}

sub fetch_module {
    my($self, $dist) = @_;

    if ($dist->{dist} eq 'perl'){
        $self->diag("skip $dist->{dist}\n");
        return;
    }

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

        my $dir = $self->unpack($file);
        next unless $dir; # unpack failed

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
    my($self, $module) = @_;

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
    return $self->search_module($module);
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

sub check_module {
    my($self, $mod, $want_ver) = @_;

    require Module::Metadata;
    my $meta = Module::Metadata->new_from_module($mod, inc => $self->{search_inc})
        or return 0, undef;

    my $version = $meta->version;
    $self->{local_versions}{$mod} = $version;

    if ($self->is_deprecated($meta)){
        return 0, $version;
    } elsif (!$want_ver or $version >= Module::Metadata::Version->new($want_ver)) {
        return 1, $version;
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
            push @install, $mod;
            $seen{$mod} = 1;
        }
    }

    if (@install) {
        $self->diag("==> Found dependencies: " . join(", ", @install) . "\n");
    }

    my @fail;
    for my $mod (@install) {
        $self->install_module($mod, $depth + 1)
            or push @fail, $mod;
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
            $self->diag_fail("Bailing out the installation for $target. Retry with --prompt or --force.");
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

    push @config_deps, %{$dist->{meta}{configure_requires} || {}};

    my $target = $dist->{meta}{name} ? "$dist->{meta}{name}-$dist->{meta}{version}" : $dist->{dir};

    $self->install_deps_bailout($target, $dist->{dir}, $depth, @config_deps)
        or return;

    $self->diag_progress("Configuring $target");

    my $configure_state = $self->configure_this($dist);

    $self->diag_ok($configure_state->{configured_ok} ? "OK" : "N/A");

    my @deps = $self->find_prereqs($dist->{meta});

    my $distname = $dist->{meta}{name} ? "$dist->{meta}{name}-$dist->{meta}{version}" : $stuff;

    $self->install_deps_bailout($distname, $dist->{dir}, $depth, @deps)
        or return;

    if ($self->{installdeps} && $depth == 0) {
        $self->diag("<== Installed dependencies for $stuff. Finishing.\n");
        return 1;
    }

    my $installed;
    if ($configure_state->{use_module_build} && -e 'Build' && -f _) {
        $self->diag_progress("Building " . ($self->{notest} ? "" : "and testing ") . "$distname for $stuff");
        $self->build([ $self->{perl}, "./Build" ]) &&
        $self->test([ $self->{perl}, "./Build", "test" ], $distname) &&
        $self->install([ $self->{perl}, "./Build", "install" ], [ "--uninst", 1 ]) &&
        $installed++;
    } elsif ($self->{make} && -e 'Makefile') {
        $self->diag_progress("Building " . ($self->{notest} ? "" : "and testing ") . "$distname for $stuff");
        $self->build([ $self->{make} ]) &&
        $self->test([ $self->{make}, "test" ], $distname) &&
        $self->install([ $self->{make}, "install" ], [ "UNINST=1" ]) &&
        $installed++;
    } else {
        my $why;
        my $configure_failed = $configure_state->{configured} && !$configure_state->{configured_ok};
        if ($configure_failed) { $why = "Configure failed for $distname." }
        elsif ($self->{make})  { $why = "The distribution doesn't have a proper Makefile.PL/Build.PL" }
        else                   { $why = "Can't configure the distribution. You probably need to have 'make'." }

        $self->diag_fail("$why See $self->{log} for details.");
        return;
    }

    if ($installed) {
        my $local   = $self->{local_versions}{$dist->{module} || ''};
        my $version = $dist->{meta}{version} || $dist->{version};
        my $reinstall = $local && ($local eq $version);

        my $how = $reinstall ? "reinstalled $distname"
                : $local     ? "installed $distname (upgraded from $local)"
                             : "installed $distname" ;
        my $msg = "Successfully $how";
        $self->diag_ok;
        $self->diag("$msg\n");
        return 1;
    } else {
        my $msg = "Building $distname failed";
        $self->diag_fail("Installing $stuff failed. See $self->{log} for details.");
        return;
    }
}

sub configure_this {
    my($self, $dist) = @_;

    my @switches;
    @switches = ("-I$self->{base}", "-MDumpedINC") if $self->{self_contained};
    local $ENV{PERL5LIB} = ''                      if $self->{self_contained};

    my $state = {};

    my $try_eumm = sub {
        if (-e 'Makefile.PL') {
            $self->chat("Running Makefile.PL\n");
            local $ENV{X_MYMETA} = 'YAML';

            # NOTE: according to Devel::CheckLib, most XS modules exit
            # with 0 even if header files are missing, to avoid receiving
            # tons of FAIL reports in such cases. So exit code can't be
            # trusted if it went well.
            if ($self->configure([ $self->{perl}, @switches, "Makefile.PL" ])) {
                $state->{configured_ok} = -e 'Makefile';
            }
            $state->{configured}++;
        }
    };

    my $try_mb = sub {
        if (-e 'Build.PL') {
            $self->chat("Running Build.PL\n");
            if ($self->configure([ $self->{perl}, @switches, "Build.PL" ])) {
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

    return $state;
}

sub safe_eval {
    my($self, $code) = @_;
    eval $code;
}

sub find_prereqs {
    my($self, $meta) = @_;

    my @deps;
    if (-e 'MYMETA.yml') {
        $self->chat("Checking dependencies from MYMETA.yml ...\n");
        my $mymeta = $self->parse_meta('MYMETA.yml');
        @deps = $self->extract_requires($mymeta);
        $meta->{$_} = $mymeta->{$_} for keys %$mymeta; # merge
    } elsif (-e '_build/prereqs') {
        $self->chat("Checking dependencies from _build/prereqs ...\n");
        my $mymeta = do { open my $in, "_build/prereqs"; $self->safe_eval(join "", <$in>) };
        @deps = $self->extract_requires($mymeta);
    }

    if (-e 'Makefile') {
        $self->chat("Finding PREREQ from Makefile ...\n");
        open my $mf, "Makefile";
        while (<$mf>) {
            if (/^\#\s+PREREQ_PM => ({.*?})/) {
                my $prereq = $self->safe_eval("no strict; +$1");
                push @deps, %$prereq if $prereq;
                last;
            }
        }
    }

    # No need to remove, but this gets in the way of signature testing :/
    unlink 'MYMETA.yml';

    return @deps;
}

sub extract_requires {
    my($self, $meta) = @_;

    my @deps;
    push @deps, %{$meta->{requires}} if $meta->{requires};
    push @deps, %{$meta->{build_requires}} if $meta->{build_requires};

    return @deps;
}

sub DESTROY {
    my $self = shift;
    $self->{at_exit}->($self) if $self->{at_exit};
}

# Utils

sub shell_quote {
    my($self, $stuff) = @_;
    $quote . $stuff . $quote;
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
sub redirect { $_[0]->{_backends}{redirect}->(@_) };
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
        $self->{_backends}{redirect} = sub {
            my $self = shift;
            my $res  = $ua->(max_redirect => 1)->simple_request(HTTP::Request->new(GET => $_[0]));
            return $res->header('Location') if $res->is_redirect;
            return;
        };
    } elsif (my $wget = $self->which('wget')) {
        $self->chat("You have $wget\n");
        $self->{_backends}{get} = sub {
            my($self, $uri) = @_;
            return $self->file_get($uri) if $uri =~ s!^file:/+!/!;
            my $q = $self->{verbose} ? '' : '-q';
            open my $fh, "$wget $uri $q -O - |" or die "wget $uri: $!";
            local $/;
            <$fh>;
        };
        $self->{_backends}{mirror} = sub {
            my($self, $uri, $path) = @_;
            return $self->file_mirror($uri, $path) if $uri =~ s!^file:/+!/!;
            my $q = $self->{verbose} ? '' : '-q';
            system "$wget --retry-connrefused $uri $q -O $path";
        };
        $self->{_backends}{redirect} = sub {
            my($self, $uri) = @_;
            my $out = `$wget --max-redirect=0 $uri 2>&1`;
            if ($out =~ /^Location: (\S+)/m) {
                return $1;
            }
            return;
        };
    } elsif (my $curl = $self->which('curl')) {
        $self->chat("You have $curl\n");
        $self->{_backends}{get} = sub {
            my($self, $uri) = @_;
            return $self->file_get($uri) if $uri =~ s!^file:/+!/!;
            my $q = $self->{verbose} ? '' : '-s';
            open my $fh, "$curl -L $q $uri |" or die "curl $uri: $!";
            local $/;
            <$fh>;
        };
        $self->{_backends}{mirror} = sub {
            my($self, $uri, $path) = @_;
            return $self->file_mirror($uri, $path) if $uri =~ s!^file:/+!/!;
            my $q = $self->{verbose} ? '' : '-s';
            system "$curl -L $uri $q -# -o $path";
        };
        $self->{_backends}{redirect} = sub {
            my($self, $uri) = @_;
            my $out = `$curl -I -s $uri 2>&1`;
            if ($out =~ /^Location: (\S+)/m) {
                return $1;
            }
            return;
        };
    } else {
        require HTTP::Lite;
        $self->chat("Falling back to HTTP::Lite $HTTP::Lite::VERSION\n");
        my $http_cb = sub {
            my($uri, $redir, $cb_gen) = @_;

            my $http = HTTP::Lite->new;

            my($data_cb, $done_cb) = $cb_gen ? $cb_gen->() : ();
            my $req = $http->request($uri, $data_cb);
            $done_cb->($req) if $done_cb;

            my $redir_count;
            while ($req == 302 or $req == 301)  {
                last if $redir_count++ > 5;
                my $loc;
                for ($http->headers_array) {
                    /Location: (\S+)/ and $loc = $1, last;
                }
                $loc or last;
                if ($loc =~ m!^/!) {
                    $uri =~ s!^(\w+?://[^/]+)/.*$!$1!;
                    $uri .= $loc;
                } else {
                    $uri = $loc;
                }

                return $uri if $redir;

                my($data_cb, $done_cb) = $cb_gen ? $cb_gen->() : ();
                $req = $http->request($uri, $data_cb);
                $done_cb->($req) if $done_cb;
            }

            return if $redir;
            return ($http, $req);
        };

        $self->{_backends}{get} = sub {
            my($self, $uri) = @_;
            return $self->file_get($uri) if $uri =~ s!^file:/+!/!;
            my($http, $req) = $http_cb->($uri);
            return $http->body;
        };

        $self->{_backends}{mirror} = sub {
            my($self, $uri, $path) = @_;
            return $self->file_mirror($uri, $path) if $uri =~ s!^file:/+!/!;

            my($http, $req) = $http_cb->($uri, undef, sub {
                open my $out, ">$path" or die "$path: $!";
                binmode $out;
                sub { print $out ${$_[1]} }, sub { close $out };
            });

            return $req;
        };

        $self->{_backends}{redirect} = sub {
            my($self, $uri) = @_;
            return $http_cb->($uri, 1);
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
            $root =~ s{^(.+)/[^/]*$}{$1};

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
            $root =~ s{^(.+)/[^/]*$}{$1};

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

sub parse_meta {
    my($self, $file) = @_;
    return eval { (Parse::CPAN::Meta::LoadFile($file))[0] } || {};
}

sub parse_meta_string {
    my($self, $yaml) = @_;
    return eval { (Parse::CPAN::Meta::Load($yaml))[0] } || {};
}

1;
