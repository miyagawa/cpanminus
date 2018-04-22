use strict;
use lib ".";
use xt::Run;
use Module::CoreList;
use Test::More;

plan skip_all => "Module::Build is in core on $]"
  if $Module::CoreList::version{$]}{"Module::Build"};

run '-Uf', 'Module::Build';

run 'Algorithm::C3@0.08';
like last_build_log, qr/installed Algorithm-C3/;

done_testing;



