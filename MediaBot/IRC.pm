package MediaBot::IRC;

use strict;

use Carp;
use POE qw(
  Component
  Component::IRC
  Component::IRC::Plugin::AutoJoin
  Component::IRC::Plugin::CycleEmpty
  Component::IRC::Plugin::Connector
);

use warnings;
use lib qw(..);
use MediaBot::Class qw(AUTOLOAD DESTROY _get_root);
use MediaBot::Log;
use MediaBot::Constants;
use MediaBot::IRC::UserRequestFilter;
use MediaBot::IRC::Sessions;
use MediaBot::IRC::Commands;
use MediaBot::IRC::Commands::Object;

our $AUTOLOAD;

my %fields = (
    _parent           => undef,
    Commands          => undef,
    Sessions          => undef,
    UserRequestFilter => undef,
);

my $nickname = 'OlumZ';
my $ircname  = 'A futur capsule?';

#my %channels = ( '#teuk' => '', );
#my @servers = ('shake.mine.nu');

my %channels = ( '#erreur404' => '', );
my @servers  = ( 'diemen.nl.eu.undernet.org' );

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
    POE::Session->create(
        object_states => [
            $s => { _start        => '_start' },
            $s => { _default      => '_default' },
            $s => { irc_msg       => 'irc_msg' },
            $s => { irc_public    => 'irc_public' },
            $s => { irc_ctcp_ping => 'irc_ctcp_ping' },
            $s => { lag_o_meter   => 'lag_o_meter' },

        ],

    );
    $s->_parent($parent);
    $s->Commands( new MediaBot::IRC::Commands($s) );
    $s->Sessions( new MediaBot::IRC::Sessions($s) );
    $s->UserRequestFilter( new MediaBot::IRC::UserRequestFilter($s) );
    return $s;
}

sub _start {

    #my ($s) = shift;
    my ( $kernel, $heap ) = @_[ KERNEL, HEAP ];

    # We create a new PoCo-IRC object
    my $irc = POE::Component::IRC->spawn(
        nick    => $nickname,
        ircname => $ircname,

        #server  => $server,
    ) or croak "Oh noooo! $!";

    $heap->{connector} = POE::Component::IRC::Plugin::Connector->new();
    $irc->plugin_add( 'Connector' => $heap->{connector} );

    #$heap->{irc} = $irc;
    # retrieve our component's object from the heap where we stashed it
    #my $irc = $heap->{irc};

    $irc->plugin_add(
        'AutoJoin',
        POE::Component::IRC::Plugin::AutoJoin->new(
            Channels          => \%channels,
            RejoinOnKick      => 1,
            Rejoin_delay      => 1,
            Retry_when_banned => 5,
        )
    );

    $irc->plugin_add( 'CycleEmpty',
        POE::Component::IRC::Plugin::CycleEmpty->new() );

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
    DEBUG( join ' ', @output );
    return;
}


sub irc_msg {
    my $s = $_[0];   
    my $user = $s->UserRequestFilter->run(@_);
    return unless $user;
    $s->Commands->dispatch( $user, IRCCMD_TYPE_PRV, @_ );
    return 0;
}

sub irc_public {
    my $s = $_[0]; 
    my $user = $s->UserRequestFilter->run(@_);
    return unless $user;
    $s->Commands->dispatch( $user, IRCCMD_TYPE_PUB, @_ );
    return 0;
}

sub lag_o_meter {
    my ( $kernel, $heap ) = @_[ KERNEL, HEAP ];
    LOG( 'Time: ' . time() . ' Lag: ' . $heap->{connector}->lag() );
    $kernel->delay( 'lag_o_meter' => 60 );
    return;
}

sub irc_ctcp_ping {
    my $s = $_[0];
    my $user = $s->UserRequestFilter->run(@_);
    return unless $user;
    my ( $sender, $where, $what ) = @_[ SENDER, ARG1 .. ARG2 ];
    my $channel = $where->[0];
    my $irc     = $sender->get_heap();      # obtain the poco's object
    DEBUG("Receive CTCP PING from " . $user->pretty_print);
    $irc->yield( ctcpreply => $user->nick => "PING $what" );
}

sub run {
    $poe_kernel->run();
}
1;
