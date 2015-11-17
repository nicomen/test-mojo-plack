use Test::More;

use Test::Mojo::Plack;
use Mojo::JSON;

use Data::Dumper;
use File::Spec;
use FindBin;
use lib File::Spec->catdir($FindBin::Bin, 'MyApp', 'lib');

plan( skip_all => 'Tests need Catalyst installed to run' ) unless eval { require 'Catalyst.pm'; };

my $t1 = Test::Mojo::Plack->new('MyApp');

$t1->get_ok("/")->status_is(200);

my $json = '{"foo":1}';
$t1->post_ok("/" => {} => json => Mojo::JSON::decode_json($json) );

is($t1->tx->res->body, $json, 'JSON comes back correctly');

done_testing;
