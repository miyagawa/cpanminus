use ExtUtils::MakeMaker;
use File::Copy;

WriteMakefile(
  NAME => 'Foo',
);

copy('META.json', 'MYMETA.json');
