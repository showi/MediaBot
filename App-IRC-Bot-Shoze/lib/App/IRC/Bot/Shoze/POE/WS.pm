package App::IRC::Bot::Shoze::POE::WS;

use strict;
use warnings;

use Carp;
use POE;
use POE::Component::IRC::Plugin qw(:ALL);

use lib qw(../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Config;
use App::IRC::Bot::Shoze::Db;
use App::IRC::Bot::Shoze::Constants;
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::POE::IRC::Out;

use Data::Dumper qw(Dumper);

our %fields = (
    _parent => undef,
    Out     => undef,
    session => undef,
    poco    => undef,
);

sub new {
    my ( $proto, $parent ) = @_;
    croak "No parent object passed as first parameter"
      unless ref($parent);
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    $s->_parent($parent);
    if (App::IRC::Bot::Shoze::Config->new->ws->{enable}) {
        $s->_init_poe();
    }
    return $s;
}

sub _init_poe () {
    my $s = shift;

    my $Config = App::IRC::Bot::Shoze::Config->new->ws;
    my $Shoze = App::IRC::Bot::Shoze->new;
    LOG(    "* Lauching web service "
          . $Config->{hostname} . ":"
          . $Config->{port} );
    LOG( "Loading SSL certificate from " . $Shoze->_path . "/data/" );
    $s->session(POE::Component::Server::TCP->new(
        Alias => "web_server",
        Port  => $Config->{port} || 9090,
        Hostname  => ( $Config->{hostname} || '127.0.0.1' ),

        # You need to have created (self) signed certificates
        # and a corresponding key file to encrypt the data with
        # SSL.

        ClientFilter => POE::Filter::Stackable->new(
            Filters => [
                POE::Filter::SSL->new(
                    crt => $Shoze->_path . 'data/server.crt',
                    key => $Shoze->_path . 'data/server.key'
                ),
                POE::Filter::HTTPD->new(),
            ]
        ),

        # The ClientInput function is called to deal with client input.
        # Because this server uses POE::Filter::SSL to encrypt the connection,
        # POE::Filter::HTTPD must be added after this to parse input.
        # ClientInput will receive first the SSL data and then the
        # add POE::Filter::HTTPD to handle the decrytped HTTP requests.

        ClientInput => sub {
            my ( $kernel, $heap, $request ) = @_[ KERNEL, HEAP, ARG0 ];
            LOG("[WS] Get request!");

            # Filter::HTTPD sometimes generates HTTP::Response objects.
            # They indicate (and contain the response for) errors that occur
            # while parsing the client's HTTP request.  It's easiest to send
            # the responses as they are and finish up.
            if ( $request->isa("HTTP::Response") ) {
                $heap->{client}->put($request);
                $kernel->yield("shutdown");
                return;
            }
            my $response = $Shoze->HTTP->dispatch($request);
            $heap->{client}->put($response);
            $kernel->yield("shutdown");
        },
        
        Started => sub {
            #print Dumper $_[HEAP];
            LOG("WS Server started on " . $_[HEAP]{listener} . ":");
            $_[HEAP]{server_status} = 1;
        },
   
        
    ));
}
