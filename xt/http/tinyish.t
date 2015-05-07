use strict;
use Test::More;
use Menlo::HTTP::Tinyish;
use File::Temp qw(tempdir);
use JSON::PP qw(decode_json);

sub read_file {
    open my $fh, "<", shift;
    join "", <$fh>;
}

for my $backend ( @Menlo::HTTP::Tinyish::Backends ) {
    diag "Testing with $backend";
    $Menlo::HTTP::Tinyish::PreferredBackend = $backend;

    my $res = Menlo::HTTP::Tinyish->new->get("http://www.cpan.org");
    is $res->{status}, 200;
    like $res->{content}, qr/Comprehensive/;

    if ($backend->supports('https')) {
        $res = Menlo::HTTP::Tinyish->new->get("https://cpan.metacpan.org");
        is $res->{status}, 200;
        like $res->{content}, qr/Comprehensive/;
    }

    my $fn = tempdir(CLEANUP => 1) . "/index.html";
    $res = Menlo::HTTP::Tinyish->new->mirror("http://www.cpan.org", $fn);
    is $res->{status}, 200;
    like read_file($fn), qr/Comprehensive/;

 SKIP: {
        skip "Wget doesn't handle mirror", 1 if $backend =~ /Wget/;
        $res = Menlo::HTTP::Tinyish->new->mirror("http://www.cpan.org", $fn);
        is $res->{status}, 304;
    }

    $res = Menlo::HTTP::Tinyish->new(agent => "Menlo/1")->get("http://httpbin.org/user-agent");
    is_deeply decode_json($res->{content}), { 'user-agent' => "Menlo/1" };

    $res = Menlo::HTTP::Tinyish->new->get("http://httpbin.org/status/404");
    is $res->{status}, 404;

    $res = Menlo::HTTP::Tinyish->new->get("http://httpbin.org/response-headers?Foo=Bar+Baz");
    is $res->{headers}{foo}, "Bar Baz";

    $res = Menlo::HTTP::Tinyish->new->get("http://httpbin.org/basic-auth/user/passwd");
    is $res->{status}, 401;

    $res = Menlo::HTTP::Tinyish->new->get("http://user:passwd\@httpbin.org/basic-auth/user/passwd");
    is $res->{status}, 200;
    is_deeply decode_json($res->{content}), { authenticated => JSON::PP::true(), user => "user" };
}

done_testing;
