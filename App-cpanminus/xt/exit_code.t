use strict;
use xt::Run;
use Test::More;

sub exit_code_is {
    my($command, $code) = @_;
    my($out, $err, $exit) = run @$command;
    is $exit >> 8, $code, "@$command";
};

exit_code_is [], 1;
exit_code_is ["--unknown-option"], 1;
exit_code_is ["--help"], 0;
exit_code_is ["Try::Tiny"], 0;
exit_code_is ["Try::Tiny"], 0;
exit_code_is ["Ghiberrish"], 1;

done_testing;


