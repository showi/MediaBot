package MediaBot::IRC;

use warnings;
use strict;

use Carp;
use POE qw(
  Component
  Component::IRC
  Component::IRC::Plugin::AutoJoin
  Component::IRC::Plugin::CycleEmpty
  Component::IRC::Plugin::Connector
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

my $nickname = 'nos';
my $ircname  = 'Wanna be my friend?';

#my %channels = ( '#roots' => '', '#root' => '' );
my @servers = ('irc.nosferat.us');

#my %channels = ( '#erreur418' => '', );
#my @servers  = ( 'diemen.nl.eu.undernet.org' );

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
        heap => { Db => $s->_parent->Db, }
    );

    #$s->Commands( new MediaBot::IRC::Commands($s) );
    #$s->Sessions( new MediaBot::IRC::Sessions($s) );
    #$s->UserRequestFilter( new MediaBot::IRC::UserRequestFilter($s) );
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
        LOG( "Adding channel " . $_->usable_name . " to AutoJoin" );
        $channels{ $_->usable_name } = $_->password,;
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
    $poe_kernel->run();
}

1;
