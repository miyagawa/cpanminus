package App::cpanminus::Dependency;
use strict;
use CPAN::Meta::Requirements;

sub from_prereqs {
    my($class, $prereqs, $phases, $types) = @_;

    my @deps;
    for my $type (@$types) {
        push @deps, $class->from_versions(
            $prereqs->merged_requirements($phases, [$type])->as_string_hash,
            $type,
        );
    }

    return @deps;
}

sub from_versions {
    my($class, $versions, $type) = @_;

    my @deps;
    while (my($module, $version) = each %$versions) {
        push @deps, $class->new($module, $version, $type)
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
