#!/usr/bin/perl

use Test::Mojo::Plack;
use Test::More;

my $t = Test::Mojo::Plack->new();

$t->get_ok('http://google.com');

my $psgi_subref = sub {
    my $env = shift;
    return [ 200, [ 'Content-Type' => 'text/plain' ], [ "Hello World" ] ],
};

my $tp = Test::Mojo::Plack->new($psgi_subref);

$tp->get_ok('/')->status_is('200')->content_type_is('text/plain')->content_is('Hello World');

done_testing;
