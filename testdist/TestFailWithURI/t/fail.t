use Test::More;

eval { require URI };
ok $@, "require URI should fail: $@";
warn $@;

done_testing;


