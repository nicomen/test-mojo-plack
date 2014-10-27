#!/usr/bin/perl

use Test::Mojo::Plack;
use Test::More;

use FindBin;
use lib "$FindBin::Bin/lib";

# TODO skip if Catalyst is not installed
my $t = Test::Mojo::Plack->new('FakeCatalystApp');

$t->get_ok('/')->status_is('200')->content_type_is('text/plain')->content_is('Hello from Catalyst');

done_testing;
