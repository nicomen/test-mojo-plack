package Test::Mojo::Plack;

use strict;
use warnings;

use Mojo::Base 'Test::Mojo';
use Mojo::Headers;
use Mojo::Transaction::HTTP;
use Mojo::URL;
use Mojo::Util qw(encode decode url_unescape);

use Class::Load qw(load_class is_class_loaded);
use List::MoreUtils;
use Scalar::Util  qw(blessed);

sub new {
    my ($class, $app_class) = @_;

    my $t = $class->SUPER::new();

    return $t unless $app_class;

    $ENV{PLACK_ENV} = 1;

    if (ref $app_class eq 'CODE') { 
        $t->{psgi_app} = sub { my $res = $app_class->(shift); sub { shift->($res); } };
    } else {
        load_class($app_class) unless is_class_loaded($app_class);
        $app_class->import;
        if ($app_class->can("_finalized_psgi_app") ) { # Catalyst
            $t->{psgi_app} = $app_class->_finalized_psgi_app;
        }
        elsif ($app_class->can("dance") ) { # Dancer 
            $t->{psgi_app} = sub {
                my $request = Dancer::Request->new( env => shift );
                my $res = Dancer->dance( $request );
                sub { shift->($res); };
            }
        }
    }
    die "Unable to instantiate application as a PSGI application: '$app_class'" unless $t->{psgi_app};

    return $t;
}

sub _request_ok {
    my ($self, $tx, $url) = @_;

    # Let Mojo::Test handle it if no app has been instantiated
    return $self->SUPER::_request_ok(@_[1..2]) unless $self->{psgi_app};

    $url = Mojo::URL->new($url);

    my $env = {
        PATH_INFO         => url_unescape($url->path || '/'),
        QUERY_STRING      => $url->query || '',
        SCRIPT_NAME       => '',
        SERVER_NAME       => $url->host,
        SERVER_PORT       => $url->port,
        SERVER_PROTOCOL   => $tx->req->version ? ('HTTP/' . $tx->req->version ) : 'HTTP/1.1',
        REMOTE_ADDR       => '127.0.0.1',
        REMOTE_HOST       => 'localhost',
        REMOTE_PORT       => int( rand(64000) + 1000 ),                   # not in RFC 3875
        REQUEST_URI       => (join '?', $url->path, $url->query) || '/',  # not in RFC 3875
        REQUEST_METHOD    => $tx->req->method,
        'psgi.version'      => [ 1, 1 ],
        'psgi.url_scheme'   => $url->scheme && $url->scheme eq 'https' ? 'https' : 'http',
        'psgi.input'        => $tx->req->body,
        'psgi.errors'       => *STDERR,
        'psgi.multithread'  => 0,
        'psgi.multiprocess' => 0,
        'psgi.run_once'     => 1,
        'psgi.streaming'    => 1,
        'psgi.nonblocking'  => 0,
    };

    for my $field ( $tx->req->headers->names ) {
        my $key = uc("HTTP_$field");
        $key =~ tr/-/_/;
        $key =~ s/^HTTP_// if $field =~ /^Content-(Length|Type)$/;

        unless ( exists $env->{$key} ) {
            $env->{$key} = $tx->req->headers->header($field);
        }
    }

    if ($env->{SCRIPT_NAME}) {
        $env->{PATH_INFO} =~ s/^\Q$env->{SCRIPT_NAME}\E/\//;
        $env->{PATH_INFO} =~ s/^\/+/\//;
    }

    if (!defined($env->{HTTP_HOST}) && $url->host) {
        $env->{HTTP_HOST} = $url->host;
        $env->{HTTP_HOST} .= ':' . $url->port
            if $url->port;
    }
    $env->{HTTP_HOST} ||= 'localhost';

  my $ret = $self->{psgi_app}->($env);
  my $res = Mojo::Message::Response->new();

  $ret->(sub {
    my ($code, $headers, $body) = @{+shift};
    my $header_hash;
    my $it = List::MoreUtils::natatime 2, @{$headers};
    while (my($k, $v) = $it->()) {
        $res->headers->append($k, $v);
    }
    $res->code($code);
    $res->body(join '', map { decode 'UTF-8', $_ } @{$body});
  });

  $self->tx(Mojo::Transaction::HTTP->new);
  $self->tx->req->env($env);
  $self->tx->res($res);

  my $err = $self->tx->error;
  Test::More::diag $err->{message}
    if !(my $ok = !$err->{message} || $err->{code}) && $err;
  my $desc = encode 'UTF-8', "@{[uc $tx->req->method]} $url";
  return $self->_test('ok', $ok, $desc);
}

=head1 NAME

Test::Mojo::Plack - Test Plack-compatible applications with Test:Mojo

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.02';

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Test::Mojo::Plack;

    my $foo = Test::Mojo::Plack->new('My::Catalyst::App');
    my $foo = Test::Mojo::Plack->new('My::Dancer::App');

    $foo->get_ok("/")->status_is(200)->content_type_is('text/html')->text_is('#footer a.author', 'mendoza@pvv.ntnu.no');

=head1 SUBROUTINES/METHODS

=head2 new

Returns a L<Test::Mojo::Plack> object that is a subclass of L<Test::Mojo>

=head1 AUTHOR

Nicolas Mendoza, C<< <mendoza at pvv.ntnu.no> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-test-mojo-plack at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Test-Mojo-Plack>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Test::Mojo::Plack

=head1 REPOSITORY

L<https://github.com/nicomen/test-mojo-plack>

=head1 ACKNOWLEDGEMENTS

Heavily inspired by L<Plack::Test> and L<Catalyst::Test> and of course L<Test::Mojo>

=head1 LICENSE AND COPYRIGHT

Copyright 2014 Nicolas Mendoza.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of Test::Mojo::Plack


