# NAME

Menlo::Legacy - Legacy internal and client support for Menlo

# SYNOPSIS

    use Menlo::CLI::Compat;

    my $app = Menlo::CLI::Compat->new;
    $app->parse_options(@ARGV);
    $app->run;

# DESCRIPTION

Menlo::Legacy is a package to install [Menlo::CLI::Compat](https://metacpan.org/pod/Menlo::CLI::Compat) which is a
compatibility library that implements the classic versino of
cpanminus, so that existing users of cpanm and API clients who depend
on the internals of cpanm (e.g. [Carton](https://metacpan.org/pod/Carton), [Carmel](https://metacpan.org/pod/Carmel) and [App::cpm](https://metacpan.org/pod/App::cpm))
can rely on the stable feature of cpanm. This way Menlo core can
evolve and refactor without breaking the downstream clients, including
`cpanm` itself.

# AUTHOR

Tatsuhiko Miyagawa <miyagawa@bulknews.net>

# COPYRIGHT

Copyright 2018- Tatsuhiko Miyagawa

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# SEE ALSO

[Menlo::CLI::Compat](https://metacpan.org/pod/Menlo::CLI::Compat)
