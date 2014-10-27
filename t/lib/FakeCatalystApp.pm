package FakeCatalystApp;

sub new {
   my $class = shift;
   bless {}, 'FakeCatalystApp';
}

my $app = sub {
    my $env = shift;
    return [ 200, [ 'Content-Type' => 'text/plain' ], [ "Hello from Catalyst" ] ],
};

sub _finalized_psgi_app {
    sub { my $res = $app->(shift); sub { shift->($res); } }
}

1;
