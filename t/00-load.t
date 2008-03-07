#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 26;

my $ID = '931145';
my $PASTE_DUMP = {
          'language' => 'Perl Source',
          'content' => "{\r\n\ttrue => sub { 1 },\r\n\tfalse => sub { 0 },\r\n\ttime  => scalar localtime(),\r\n}",
          'post_date' => 'Thursday, March 6th, 2008 at 4:57:44pm MST',
          'name' => 'Zoffix',
};

BEGIN {
    use_ok('Carp');
    use_ok('URI');
    use_ok('LWP::UserAgent');
    use_ok('HTML::TokeParser::Simple');
    use_ok('Class::Data::Accessor');
    use_ok('HTML::Entities');
	use_ok( 'WWW::PastebinCa::Retrieve' );
}

diag( "Testing WWW::PastebinCa::Retrieve $WWW::PastebinCa::Retrieve::VERSION, Perl $], $^X" );

use WWW::PastebinCa::Retrieve;
my $paster = WWW::PastebinCa::Retrieve->new( timeout => 10 );
isa_ok($paster, 'WWW::PastebinCa::Retrieve');
can_ok($paster, qw(
    new
    retrieve
    error
    results
    html_content
    id
    uri
    timeout
    ua
    _parse
    _set_error
    response
    )
);

SKIP: {
    my $ret = $paster->retrieve($ID)
        or skip "Got error on ->retrieve($ID): " . $paster->error, 17;

    # this one will be constantly changing... get rid of it
    my $age = delete $ret->{age};
    ok( defined $age, '{age} in $ret');

    SKIP: {
        my $ret2 = $paster->retrieve("http://pastebin.ca/$ID")
            or skip "Got error on ->retrieve('http://pastebin.ca/$ID'): "
                        . $paster->error, 3;
        ok( exists $ret2->{age}, '->{age} in $ret2' );
        ok( defined delete $ret2->{age}, '->{age} is defined in $ret2');
        is_deeply(
            $ret,
            $ret2,
            'calls with ID and URI must return the same'
        );
    }

    is_deeply(
        $ret,
        $PASTE_DUMP,
        q|dump from Dumper must match ->retrieve()'s response|,
    );

    for ( qw(language content post_date name) ) {
        ok( exists $ret->{$_}, "$_ key must exist in the return" );
    }

    is_deeply(
        $ret,
        $paster->results,
        '->results() must now return whatever ->retrieve() returned',
    );

    is(
        $paster->id,
        $ID,
        'paste ID must match the return from ->id()',
    );

    isa_ok( $paster->uri, 'URI::http', '->uri() method' );

    is(
        $paster->uri,
        "http://pastebin.ca/$ID",
        'uri() must contain a URI to the paste',
    );
    isa_ok( $paster->response, 'HTTP::Response', '->response() method' );

    like( $paster->html_content,
     qr|<html xmlns=[^>]+>.*?<head>.*?</head>.*?<body>.*?</body>.*?</html>|s,
        '->html_content() method'
    );
    is(
        $paster->timeout,
        10,
        '->timeout() method',
    );
    isa_ok( $paster->ua, 'LWP::UserAgent', '->ua() method' );
} # SKIP{}





