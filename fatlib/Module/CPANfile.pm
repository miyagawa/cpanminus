package Module::CPANfile;
use strict;
use warnings;
use Cwd;
use Carp ();

our $VERSION = '0.9030';

sub new {
    my($class, $file) = @_;
    bless {}, $class;
}

sub load {
    my($proto, $file) = @_;
    my $self = ref $proto ? $proto : $proto->new;
    $self->{file} = $file || "cpanfile";
    $self->parse;
    $self;
}

sub save {
    my($self, $path) = @_;

    open my $out, ">", $path or die "$path: $!";
    print {$out} $self->to_string;
}

sub parse {
    my $self = shift;

    my $file = Cwd::abs_path($self->{file});
    $self->{result} = Module::CPANfile::Environment::parse($file) or die $@;
}

sub from_prereqs {
    my($proto, $prereqs) = @_;

    my $self = $proto->new;
    $self->{result} = Module::CPANfile::Result->from_prereqs($prereqs);

    $self;
}

sub features {
    my $self = shift;
    map $self->feature($_), keys %{$self->{result}{features}};
}

sub feature {
    my($self, $identifier) = @_;

    my $data = $self->{result}{features}{$identifier}
      or Carp::croak("Unknown feature '$identifier'");

    require CPAN::Meta::Feature;
    CPAN::Meta::Feature->new($data->{identifier}, {
        description => $data->{description},
        prereqs => $data->{spec},
    });
}

sub prereqs { shift->prereq }

sub prereqs_with {
    my($self, @feature_identifiers) = @_;

    my $prereqs = $self->prereqs;
    my @others = map { $self->feature($_)->prereqs } @feature_identifiers;

    $prereqs->with_merged_prereqs(\@others);
}

sub prereq {
    my $self = shift;
    require CPAN::Meta::Prereqs;
    CPAN::Meta::Prereqs->new($self->prereq_specs);
}

sub prereq_specs {
    my $self = shift;
    $self->{result}{spec};
}

sub merge_meta {
    my($self, $file, $version) = @_;

    require CPAN::Meta;

    $version ||= $file =~ /\.yml$/ ? '1.4' : '2';

    my $prereq = $self->prereqs;

    my $meta = CPAN::Meta->load_file($file);
    my $prereqs_hash = $prereq->with_merged_prereqs($meta->effective_prereqs)->as_string_hash;
    my $struct = { %{$meta->as_struct}, prereqs => $prereqs_hash };

    CPAN::Meta->new($struct)->save($file, { version => $version });
}

sub _dump {
    my $str = shift;
    require Data::Dumper;
    chomp(my $value = Data::Dumper->new([$str])->Terse(1)->Dump);
    $value;
}

sub to_string {
    my($self, $include_empty) = @_;

    my $prereqs = $self->{result}{spec};

    my $code = '';
    $code .= $self->_dump_prereqs($self->{result}{spec}, $include_empty);

    for my $feature (values %{$self->{result}{features}}) {
        $code .= sprintf "feature %s, %s => sub {\n", _dump($feature->{identifier}), _dump($feature->{description});
        $code .= $self->_dump_prereqs($feature->{spec}, $include_empty, 4);
        $code .= "}\n\n";
    }

    $code =~ s/\n+$/\n/s;
    $code;
}

sub _dump_prereqs {
    my($self, $prereqs, $include_empty, $base_indent) = @_;

    my $code = '';
    for my $phase (qw(runtime configure build test develop)) {
        my $indent = $phase eq 'runtime' ? '' : '    ';
        $indent = (' ' x ($base_indent || 0)) . $indent;

        my($phase_code, $requirements);
        $phase_code .= "on $phase => sub {\n" unless $phase eq 'runtime';

        for my $type (qw(requires recommends suggests conflicts)) {
            for my $mod (sort keys %{$prereqs->{$phase}{$type}}) {
                my $ver = $prereqs->{$phase}{$type}{$mod};
                $phase_code .= $ver eq '0'
                             ? "${indent}$type '$mod';\n"
                             : "${indent}$type '$mod', '$ver';\n";
                $requirements++;
            }
        }

        $phase_code .= "\n" unless $requirements;
        $phase_code .= "};\n" unless $phase eq 'runtime';

        $code .= $phase_code . "\n" if $requirements or $include_empty;
    }

    $code =~ s/\n+$/\n/s;
    $code;
}

package Module::CPANfile::Environment;
use strict;
use Carp ();

my @bindings = qw(
    on requires recommends suggests conflicts
    feature
    osname
    configure_requires build_requires test_requires author_requires
);

my $file_id = 1;

sub import {
    my($class, $result_ref) = @_;
    my $pkg = caller;

    $$result_ref = Module::CPANfile::Result->new;
    for my $binding (@bindings) {
        no strict 'refs';
        *{"$pkg\::$binding"} = sub { $$result_ref->$binding(@_) };
    }
}

sub parse {
    my $file = shift;

    my $code = do {
        open my $fh, "<", $file or die "$file: $!";
        join '', <$fh>;
    };

    my($res, $err);

    {
        local $@;
        $res = eval sprintf <<EVAL, $file_id++;
package Module::CPANfile::Sandbox%d;
no warnings;
my \$_result;
BEGIN { import Module::CPANfile::Environment \\\$_result };

# line 1 "$file"
$code;

\$_result;
EVAL
        $err = $@;
    }

    if ($err) { die "Parsing $file failed: $err" };

    return $res;
}

package Module::CPANfile::Result;
use strict;

sub from_prereqs {
    my($class, $spec) = @_;
    bless {
        phase => 'runtime',
        spec => $spec,
    }, $class;
}

sub new {
    bless {
        phase => 'runtime', # default phase
        features => {},
        feature => undef,
        spec  => {},
    }, shift;
}

sub on {
    my($self, $phase, $code) = @_;
    local $self->{phase} = $phase;
    $code->()
}

sub feature {
    my($self, $identifier, $description, $code) = @_;

    # shortcut: feature identifier => sub { ... }
    if (@_ == 3 && ref($description) eq 'CODE') {
        $code = $description;
        $description = $identifier;
    }

    unless (ref $description eq '' && ref $code eq 'CODE') {
        Carp::croak("Usage: feature 'identifier', 'Description' => sub { ... }");
    }

    local $self->{feature} = $self->{features}{$identifier}
      = { identifier => $identifier, description => $description, spec => {} };
    $code->();
}

sub osname { die "TODO" }

sub requirement_for {
    my ($self, $module, @args) = @_;

    my $requirement = 0;
    $requirement = shift @args if @args % 2;

    return Module::CPANfile::Requirement->new(
        name    => $module,
        version => $requirement,
        @args,
    );
}

sub requires {
    my($self, $module, @args) = @_;
    ($self->{feature} ? $self->{feature}{spec} : $self->{spec})
      ->{$self->{phase}}{requires}{$module} = $self->requirement_for($module, @args);
}

sub recommends {
    my($self, $module, @args) = @_;
    ($self->{feature} ? $self->{feature}{spec} : $self->{spec})
      ->{$self->{phase}}{recommends}{$module} = $self->requirement_for($module, @args);
}

sub suggests {
    my($self, $module, @args) = @_;
    ($self->{feature} ? $self->{feature}{spec} : $self->{spec})
      ->{$self->{phase}}{suggests}{$module} = $self->requirement_for($module, @args);
}

sub conflicts {
    my($self, $module, @args) = @_;
    ($self->{feature} ? $self->{feature}{spec} : $self->{spec})
      ->{$self->{phase}}{conflicts}{$module} = $self->requirement_for($module, @args);
}

# Module::Install compatible shortcuts

sub configure_requires {
    my($self, @args) = @_;
    $self->on(configure => sub { $self->requires(@args) });
}

sub build_requires {
    my($self, @args) = @_;
    $self->on(build => sub { $self->requires(@args) });
}

sub test_requires {
    my($self, @args) = @_;
    $self->on(test => sub { $self->requires(@args) });
}

sub author_requires {
    my($self, @args) = @_;
    $self->on(develop => sub { $self->requires(@args) });
}

package Module::CPANfile::Requirement;
use strict;
use overload '""' => \&as_string, fallback => 1;

sub as_string { shift->{version} }

sub as_hashref {
    my $self = shift;
    return +{ %$self };
}

sub new {
    my ($class, %args) = @_;

    # requires 'Plack';
    # requires 'Plack', '0.9970';
    # requires 'Plack', git => 'git://github.com/plack/Plack.git', rev => '0.9970';
    # requires 'Plack', '0.9970', git => 'git://github.com/plack/Plack.git', rev => '0.9970';

    $args{version} ||= 0;

    bless +{
        name    => $args{name},
        version => $args{version},
        (exists $args{git} ? (git => $args{git}) : ()),
        (exists $args{rev} ? (rev => $args{rev}) : ()),
    }, $class;
}

sub name    { shift->{name} }
sub version { shift->{version} }

sub git { shift->{git} }
sub rev { shift->{rev} }

package Module::CPANfile;

1;

__END__

=head1 NAME

Module::CPANfile - Parse cpanfile

=head1 SYNOPSIS

  use Module::CPANfile;

  my $file = Module::CPANfile->load("cpanfile");
  my $prereqs = $file->prereqs; # CPAN::Meta::Prereqs object

  my @features = $file->features; # CPAN::Meta::Feature objects
  my $merged_prereqs = $file->prereqs_with(@identifiers); # CPAN::Meta::Prereqs

  $file->merge_meta('MYMETA.json');

=head1 DESCRIPTION

Module::CPANfile is a tool to handle L<cpanfile> format to load application
specific dependencies, not just for CPAN distributions.

=head1 METHODS

=over 4

=item load

  $file = Module::CPANfile->load;
  $file = Module::CPANfile->load('cpanfile');

Load and parse a cpanfile. By default it tries to load C<cpanfile> in
the current directory, unless you pass the path to its argument.

=item from_prereqs

  $file = Module::CPANfile->from_prereqs({
    runtime => { requires => { DBI => '1.000' } },
  });

Creates a new Module::CPANfile object from prereqs hash you can get
via L<CPAN::Meta>'s C<prereqs>, or L<CPAN::Meta::Prereqs>'
C<as_string_hash>.

  # read MYMETA, then feed the prereqs to create Module::CPANfile
  my $meta = CPAN::Meta->load_file('MYMETA.json');
  my $file = Module::CPANfile->from_prereqs($meta->prereqs);

  # load cpanfile, then recreate it with round-trip
  my $file = Module::CPANfile->load('cpanfile');
  $file = Module::CPANfile->from_prereqs($file->prereq_specs);
                                    # or $file->prereqs->as_string_hash

=item prereqs

Returns L<CPAN::Meta::Prereqs> object out of the parsed cpanfile.

=item prereq_specs

Returns a hash reference that should be passed to C<< CPAN::Meta::Prereqs->new >>.

=item features

Returns a list of features available in the cpanfile as L<CPAN::Meta::Feature>.

=item prereqs_with(@identifiers)

Retuens L<CPAN::Meta::Prereqs> object, with merged prereqs for
features identified with the C<@identifiers>.

=item to_string($include_empty)

  $file->to_string;
  $file->to_string(1);

Returns a canonical string (code) representation for cpanfile. Useful
if you want to convert L<CPAN::Meta::Prereqs> to a new cpanfile.

  # read MYMETA's prereqs and print cpanfile representation of it
  my $meta = CPAN::Meta->load_file('MYMETA.json');
  my $file = Module::CPANfile->from_prereqs($meta->prereqs);
  print $file->to_sring;

By default, it omits the phase where there're no modules
registered. If you pass the argument of a true value, it will print
them as well.

=item save

  $file->save('cpanfile');

Saves the currently loaded prereqs as a new C<cpanfile> by calling
C<to_string>. Beware B<this method will overwrite the existing
cpanfile without any warning or backup>. Taking a backup or giving
warnings to users is a caller's responsibility.

  # Read MYMETA.json and creates a new cpanfile
  my $meta = CPAN::Meta->load_file('MYMETA.json');
  my $file = Module::CPANfile->from_prereqs($meta->prereqs);
  $file->save('cpanfile');

=item merge_meta

  $file->merge_meta('META.yml');
  $file->merge_meta('MYMETA.json', '2.0');

Merge the effective prereqs with Meta speicifcation loaded from the
given META file, using CPAN::Meta. You can specify the META spec
version in the second argument, which defaults to 1.4 in case the
given file is YAML, and 2 if it is JSON.

=back

=head1 AUTHOR

Tatsuhiko Miyagawa

=head1 SEE ALSO

L<cpanfile>, L<CPAN::Meta>, L<CPAN::Meta::Spec>

=cut
