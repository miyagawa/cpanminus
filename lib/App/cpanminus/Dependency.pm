package App::cpanminus::Dependency;
use strict;
use CPAN::Meta::Requirements;

sub from_prereqs {
    my($class, $prereq, $phases, $types) = @_;

    my @deps;

    for my $type (@$types) {
        my $req = CPAN::Meta::Requirements->new;
        $req->add_requirements($prereq->requirements_for($_, $type))
          for @$phases;

        push @deps, $class->from_versions($req->as_string_hash, $type);
    }

    return @deps;
}

sub from_versions {
    my($class, $versions, $type) = @_;

    my @deps;
    for my $module (sort { lc $a cmp lc $b } keys %$versions) {
        push @deps, $class->new($module, $versions->{$module}, $type);
    }

    @deps;
}

sub new {
    my($class, $module, $version, $type) = @_;

    bless {
        module => $module,
        version => $version,
        type => $type || 'requires',
    }, $class;
}

sub module  { $_[0]->{module} }
sub version { $_[0]->{version} }
sub type    { $_[0]->{type} }

sub is_requirement {
    $_[0]->{type} eq 'requires';
}

1;
