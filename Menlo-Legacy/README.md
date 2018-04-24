# NAME

Menlo::Legacy - Legacy internal and client support for Menlo

# DESCRIPTION

Menlo::Legacy is a package to install [Menlo::CLI::Compat](https://metacpan.org/pod/Menlo::CLI::Compat) which is a
compatibility library that implements the classic version of cpanminus
internals and behavios. This is so that existing users of cpanm and
API clients such as [Carton](https://metacpan.org/pod/Carton), [Carmel](https://metacpan.org/pod/Carmel) and [App::cpm](https://metacpan.org/pod/App::cpm)) can rely on
the stable features and specific behaviors of cpanm.

This way Menlo can evolve and be refactored without the fear of
breaking any downstream clients, including `cpanm` itself.

# AUTHOR

Tatsuhiko Miyagawa <miyagawa@bulknews.net>

# COPYRIGHT

Copyright 2018- Tatsuhiko Miyagawa

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# SEE ALSO

[Menlo::CLI::Compat](https://metacpan.org/pod/Menlo::CLI::Compat)
