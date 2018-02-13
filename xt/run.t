use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use App::cpanminus::script;

$ENV{PERL_CPANM_HOME} = tempdir(CLEANUP => 1);
local $| = 1;
my $script = new_ok('App::cpanminus::script',
  [verbose => 0, log => "$ENV{PERL_CPANM_HOME}/build.log"]);

is $script->run(['not-a-command', 'that runs']), '', "nothing good here";
is $script->run('not-a-command that runs'), '', "nothing good here again";

is $script->run('echo hello world'), 1, 'good';
is $script->run([qw{echo hello world}]), 1, 'ran ok';

my @lines;
open my $fh, '<', $script->{log};
while(<$fh>) { push @lines, $_; }

like $lines[0], qr/Failed\sto\srun/, 'failed to run message';
like $lines[1], qr/FAIL\sFailed\sto\srun/, 'failed to run message';
like $lines[2], qr/^sh:\snot\-a\-command/, 'failed through shell';
like $lines[3], qr/^hello\sworld/, 'success';
like $lines[4], qr/^hello\sworld/, 'success';

done_testing;
