package App::IRC::Bot::Shoze::POE;

use warnings;
use strict;

use Carp;

use POE qw(
  Component
  Component::IRC
  Component::IRC::Plugin::AutoJoin
  Component::IRC::Plugin::CycleEmpty
  Component::IRC::Plugin::Connector
  Component::Server::TCP
  Filter::Stream
  Filter::SSL
);

use Data::Dumper;

use lib qw(..);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::Constants;;

use POE::Component::IRC::Plugin qw( :ALL );
use App::IRC::Bot::Shoze::POE::IRC;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::Sessions;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::Dispatch;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::PluginsManagement;

our $AUTOLOAD;

my %fields = (
    _parent  => undef,
    #Commands => undef,
    #Sessions => undef,
    IRC      => undef,
);

# IRC
#my @servers  = ('irc.nosferat.us');
#
## WS
#my @ports = qw(http https);
#my $host  = 'localhost';
#our $port = 9010;

sub new {
    my ( $proto, $parent ) = @_;
    DEBUG( "Creating new " . __PACKAGE__ );
    croak "No parent specified" unless ref $parent;
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    $s->_parent($parent);
    
    # IRC
    ######
    if ( $s->_parent->Config->irc->{enable} ) {
        LOG("* Connecting to irc network");
        my $id = POE::Session->create(
            object_states => [
                $s => { _start        => '_start' },
                $s => { _default      => '_default' },
                $s => { irc_ctcp_ping => 'irc_ctcp_ping' },
                $s => { lag_o_meter   => 'lag_o_meter' },
            ],
            heap => {}
        )->ID;
        #$s->IRC(new App::IRC::Bot::Shoze::POE::IRC($s));
        #$s->IRC->session_id($id);
    }

    # WS
    #####
    if ( $s->_parent->Config->ws->{enable} ) {
        LOG(    "* Lauching web service "
              . $s->_parent->Config->ws->{host} . ":"
              . $s->_parent->Config->ws->{port} );
        LOG("Loading SSL certificate from " .  $s->_parent->_path . "/data/");
        POE::Component::Server::TCP->new(
            Alias => "web_server",
            Port  => $s->_parent->Config->ws->{port} || 9090,
            Host  => (
                $s->_parent->Config->ws->{host} || '127.0.0.1'
            ),

            # You need to have created (self) signed certificates
            # and a corresponding key file to encrypt the data with
            # SSL.
          
            ClientFilter => POE::Filter::Stackable->new(
                Filters => [
                    POE::Filter::SSL->new(
                        crt => $s->_parent->_path . '/data/server.crt',
                        key => $s->_parent->_path . '/data/server.key'
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
                my $response = $s->_parent->REST->dispatch($request);
                $heap->{client}->put($response);
                $kernel->yield("shutdown");
            }
        );
    }
    return $s;
}

sub _start {
    my ( $kernel, $heap, $s ) = @_[ KERNEL, HEAP, OBJECT ];

    if ( $s->_parent->Config->irc->{enable} ) {

        # We create a new PoCo-IRC object
        my $irc = POE::Component::IRC->spawn(
            nick => $s->_parent->Config->irc->{nick}
              || $s->_parent->Config->irc->{altnick}
              || 'shoze',
            ircname =>  $s->_parent->Config->irc->{name} || 'shoze',

            #server  => $server,
        ) or croak "Oh noooo! $!";
        $s->IRC(new App::IRC::Bot::Shoze::POE::IRC($s));
        $s->IRC->poco($irc);
        $irc->{Shoze} = $s->_parent;
        $irc->{database}   = $s->_parent->Db;
        $irc->{Config}     = $s->_parent->Config;
        $heap->{connector} = POE::Component::IRC::Plugin::Connector->new();
        $irc->plugin_add( 'Connector' => $heap->{connector} );

        # Our plugins system
        $irc->plugin_add( 'BotCmdPlus',
            new App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus() );

        $irc->plugin_add( 'BotCmdPlus_Sessions',
            new App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::Sessions()
        );

        $irc->plugin_add( 'BotCmdPlus_Dispatch',
            new App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::Dispatch()
        );

        $irc->plugin_add(
            'BotCmdPlus_PluginsManagement',
            new
              App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::PluginsManagement(
              )
        );

        # End of our plugins
        my %channels;
        for ( $irc->{database}->Channels->list ) {
            LOG( "[IRC] Autojoin " . $_->_usable_name );
            $channels{ $_->_usable_name } = $_->password,;
        }
        $irc->plugin_add(
            'AutoJoin',
            POE::Component::IRC::Plugin::AutoJoin->new(
                Channels          => \%channels,
                RejoinOnKick      => 1,
                Rejoin_delay      => 1,
                Retry_when_banned => 5,
            )
        );
        #my $aj = $irc->plugin_get('AutoJoin');
        my $server = $s->_parent->Config->irc->{servers}->[0]->{host} .":".$s->_parent->Config->irc->{servers}->[0]->{port};
        LOG("* IRC server: $server");
        $irc->yield( register => 'all' );
        $irc->yield( connect => { Server =>  $s->_parent->Config->irc->{servers}->[0]->{host} } );
        $kernel->delay( 'lag_o_meter' => 60 );
    }
    return;
}

sub _default {
    my ( $event, $args ) = @_[ ARG0 .. $#_ ];
    my @output = ("$event: ");
    for my $arg (@$args) {
        if ( ref $arg eq 'ARRAY' ) {
            push( @output, '[' . join( ', ', @$arg ) . ']' );
        }
        else {
            push( @output, "'$arg'" ) if defined $arg;
        }
    }
    DEBUG( join( ' ', @output ), 4 );
    return;
}

sub lag_o_meter {
    my ( $kernel, $heap ) = @_[ KERNEL, HEAP ];
    LOG( '[IRC] AutoReco ' . time() . ' Lag: ' . $heap->{connector}->lag() );
    $kernel->delay( 'lag_o_meter' => 60 );
    return;
}

sub irc_ctcp_ping {
    my $s = $_[0];
    my ( $sender, $who, $where, $what ) = @_[ SENDER, ARG0 .. ARG2 ];
    my $nick    = ( split /!/, $who )[0];
    my $channel = $where->[0];
    my $irc     = $sender->get_heap();      # obtain the poco's object
    $irc->yield( ctcpreply => $nick => "PING $what" );
}

sub run {
    LOG("[POE] starting\n");
    $poe_kernel->run();
}

sub stop {
    LOG("[POE] starting\n");
    $poe_kernel->stop();
}
1;
