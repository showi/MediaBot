package MediaBot::POE;

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
use MediaBot::Class qw(AUTOLOAD DESTROY _get_root);
use MediaBot::Log;
use MediaBot::Constants;

#use MediaBot::IRC::UserRequestFilter;
#use MediaBot::IRC::Sessions;
#use MediaBot::IRC::Commands;
#use MediaBot::IRC::Commands::Object;

use POE::Component::IRC::Plugin qw( :ALL );
use MediaBot::IRC::BotCmdPlus;
use MediaBot::IRC::BotCmdPlus::Plugins::Sessions;
use MediaBot::IRC::BotCmdPlus::Plugins::Dispatch;
use MediaBot::IRC::BotCmdPlus::Plugins::PluginsManagement;

our $AUTOLOAD;

my %fields = (
    _parent           => undef,
    Commands          => undef,
    Sessions          => undef,
    UserRequestFilter => undef,
);

# IRC
my $nickname = 'nos';
my $ircname  = 'Wanna be my friend?';
my @servers  = ('irc.nosferat.us');

# WS
my @ports = qw(http https);
my $host  = 'localhost';
our $port = 9010;

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
    POE::Session->create(
        object_states => [
            $s => { _start   => '_start' },
            $s => { _default => '_default' },

            #  $s => { irc_msg       => 'irc_msg' },
            #  $s => { irc_public    => 'irc_public' },
            $s => { irc_ctcp_ping => 'irc_ctcp_ping' },
            $s => { lag_o_meter   => 'lag_o_meter' },

            # $s => { irc_chanmode   => 'irc_chanmode' },

        ],
        heap => {  }
    );
   
 POE::Component::Server::TCP->new(
  Alias => "web_server",
  Port  => 9090,

  # You need to have created (self) signed certificates
  # and a corresponding key file to encrypt the data with
  # SSL.

  ClientFilter => POE::Filter::Stackable->new(
    Filters => [
      POE::Filter::SSL->new(crt => 'data/server.crt', key => 'data/server.key'),
      POE::Filter::HTTPD->new(),
    ]
  ),

  # The ClientInput function is called to deal with client input.
  # Because this server uses POE::Filter::SSL to encrypt the connection,
  # POE::Filter::HTTPD must be added after this to parse input.
  # ClientInput will receive first the SSL data and then the
  # add POE::Filter::HTTPD to handle the decrytped HTTP requests.

  ClientInput => sub {
    my ($kernel, $heap, $request) = @_[KERNEL, HEAP, ARG0];

    # Filter::HTTPD sometimes generates HTTP::Response objects.
    # They indicate (and contain the response for) errors that occur
    # while parsing the client's HTTP request.  It's easiest to send
    # the responses as they are and finish up.

    if ($request->isa("HTTP::Response")) {
      $heap->{client}->put($request);
      $kernel->yield("shutdown");
      return;
    }

    # The request is real and fully formed.  Build content based on
    # it.  Insert your favorite template module here, or write your
    # own. :)
    my $response = $s->_parent->REST->dispatch($request);
 
#    my $request_fields = '';
#    $request->headers()->scan(
#      sub {
#        my ($header, $value) = @_;
#        $request_fields .= "<tr><td>$header</td><td>$value</td></tr>";
#      }
#    );
#
#    $response = HTTP::Response->new(200);
#    $response->push_header('Content-type', 'text/html');
#    $response->content(
#
#      # Break the HTML tag for the wiki.
#      "<"
#        . "html><head><title>Your Request</title></head>"
#        . "<body>Details about your request:"
#        . "<table border='1'>$request_fields</table>"
#        . "</body></html>"
#    );
#
#    # Once the content has been built, send it back to the client
#    # and schedule a shutdown.

    $heap->{client}->put($response);
    $kernel->yield("shutdown");
  }
);
    return $s;
}

sub _start {
    my ( $kernel, $heap, $s ) = @_[ KERNEL, HEAP, OBJECT ];

    # We create a new PoCo-IRC object
    my $irc = POE::Component::IRC->spawn(
        nick    => $nickname,
        ircname => $ircname,

        #server  => $server,
    ) or croak "Oh noooo! $!";

    #$s->{irc} = $irc;
    print "self: " . $_[0] . "\n";
    $irc->{database}   = $s->_parent->Db;
    $heap->{connector} = POE::Component::IRC::Plugin::Connector->new();
    $irc->plugin_add( 'Connector' => $heap->{connector} );

    # Our plugins system
    $irc->plugin_add( 'BotCmdPlus', new MediaBot::IRC::BotCmdPlus() );

    $irc->plugin_add( 'BotCmdPlus_Sessions',
        new MediaBot::IRC::BotCmdPlus::Plugins::Sessions() );

    $irc->plugin_add( 'BotCmdPlus_Dispatch',
        new MediaBot::IRC::BotCmdPlus::Plugins::Dispatch() );

    $irc->plugin_add( 'BotCmdPlus_PluginsManagement',
        new MediaBot::IRC::BotCmdPlus::Plugins::PluginsManagement() );

    # End of our plugins
    my %channels;
    for ( $irc->{database}->Channels->list ) {
        LOG( "Adding channel " . $_->_usable_name . " to AutoJoin" );
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
    my $aj = $irc->plugin_get('AutoJoin');
    print Dumper $aj;
    $irc->yield( register => 'all' );
    $irc->yield( connect => { Server => $servers[0] } );
    $kernel->delay( 'lag_o_meter' => 60 );
    


    # WS
    
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
    DEBUG( join ' ', @output, 2 );
    return;
}

sub lag_o_meter {
    my ( $kernel, $heap ) = @_[ KERNEL, HEAP ];
    LOG( 'Time: ' . time() . ' Lag: ' . $heap->{connector}->lag() );
    $kernel->delay( 'lag_o_meter' => 60 );
    return;
}

sub irc_ctcp_ping {
    my $s = $_[0];

    #my $user = $s->UserRequestFilter->run(@_);
    #return unless $user;
    my ( $sender, $who, $where, $what ) = @_[ SENDER, ARG0 .. ARG2 ];
    my $nick    = ( split /!/, $who )[0];
    my $channel = $where->[0];
    my $irc     = $sender->get_heap();      # obtain the poco's object
         #DEBUG( "Receive CTCP PING from " . $user->pretty_print );
    $irc->yield( ctcpreply => $nick => "PING $what" );
}

sub run {
    LOG("RUNNING");
    $poe_kernel->run();
}

1;
