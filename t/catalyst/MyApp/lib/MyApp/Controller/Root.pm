package MyApp::Controller::Root;
use Moose;
use namespace::autoclean;

use Encode;

BEGIN { extends 'Catalyst::Controller' }

__PACKAGE__->config(namespace => '');

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    if ($c->request->method eq 'GET') {
        # Hello World
        $c->response->body( $c->welcome_message );
    } elsif ($c->request->method eq 'POST') {
         $c->response->headers->header('Content-Type' => $c->request->headers->header('Content-Type'));
         $c->response->body($c->request->body);
    }
}

sub default :Path {
    my ( $self, $c ) = @_;
    $c->response->body( 'Page not found' );
    $c->response->status(404);
}

sub utf8 :Path :Args(1) {
    my ( $self, $c ) = @_;

    $c->stash(foo => decode_utf8("\x{e2}\x{80}\x{93}"));
    $c->forward('View::JSON');
}

sub end : ActionClass('RenderView') {}

__PACKAGE__->meta->make_immutable;

1;
