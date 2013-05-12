use inc::Module::Install;
name 'Hash-MultiValue';
all_from 'lib/Hash/MultiValue.pm';
readme_from 'lib/Hash/MultiValue.pm'; # Module::Install::ReadmeFromPod
build_requires 'Test::More';
use_test_base;                        # Module::Install::TestBase
auto_include_deps;
author_tests('xt');                   # Module::Install::AuthorTests
auto_set_repository;                  # Module::Install::Repository
WriteAll;
