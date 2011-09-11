package App::IRC::Bot::Shoze::POE::IRC;

use strict;
use warnings;

use Carp;
use POE qw(
  Component
  Component::IRC
  Component::IRC::Plugin::AutoJoin
  Component::IRC::Plugin::CycleEmpty
  Component::IRC::Plugin::Connector
);

use POE::Component::IRC::Plugin qw(:ALL);

use lib qw(../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Constants;
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::POE::IRC::Out;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::PluginsManagement;

use App::IRC::Bot::Shoze::POE::IRC::Apero;


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
    if ( $s->_get_root->Config->irc->{enable} ) {
        $s->_init_poe();
    }
    return $s;
}

sub _init_poe () {
    my $s = shift;

    LOG("* Connecting to irc network");
    $s->session(
        POE::Session->create(
            #alias         => 'irc',
            object_states => [
                $s => { _start        => '_start' },
                $s => { _stop         => '_stop' },
                $s => { _default      => '_default' },
                $s => { irc_ctcp_ping => 'irc_ctcp_ping' },
                $s => { lag_o_meter   => 'lag_o_meter' },
            ],
            heap => {}
        )
    );
    $s->Out( new App::IRC::Bot::Shoze::POE::IRC::Out($s) )
      unless $s->Out;
}

sub _stop {
    DEBUG( "Deleting session with alias " . $_[OBJECT]->alias, 1 );
    delete $_[OBJECT]->{session};
}

sub _start {
    my ( $kernel, $heap, $s ) = @_[ KERNEL, HEAP, OBJECT ];

    #if ( $s->_parent->Config->irc->{enable} ) {

    my $Shoze = $s->_get_root;
    LOG("Starting POE::IRC($Shoze)");
    # We create a new PoCo-IRC object
    my $irc = POE::Component::IRC->spawn(
      
        nick => $Shoze->Config->irc->{nick}
          || $Shoze->Config->irc->{altnick}
          || 'shoze',
        ircname => $Shoze->Config->irc->{name}
          || 'shoze',

        #server  => $server,
    ) or croak "Oh noooo! $!";
    #$s->( new App::IRC::Bot::Shoze::POE::IRC($s) );
    $s->poco($irc);
    $irc->{Shoze}      = $Shoze;
    $irc->{database}   = $Shoze->Db;
    $irc->{Config}     = $Shoze->Config;
    $heap->{connector} = POE::Component::IRC::Plugin::Connector->new();
    $irc->plugin_add( 'Connector' => $heap->{connector} );

    # Our plugins system
    $irc->plugin_add( 'BotCmdPlus',
        new App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus($s) );

#    $irc->plugin_add( 'BotCmdPlus_Sessions',
#        new App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Sessions($s) );
#
#    $irc->plugin_add( 'BotCmdPlus_Dispatch',
#        new App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Dispatch($s) );

    $irc->plugin_add(
        'BotCmdPlus_PluginsManagement',
        new
          App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::PluginsManagement(
            $s
          )
    );

    $irc->plugin_add( 'Apero', new App::IRC::Bot::Shoze::POE::IRC::Apero($s) );

    # End of our plugins
    my %channels;
    for ( $Shoze->Db->Channels->list ) {
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
    my $server =
        $Shoze->Config->irc->{servers}->[0]->{host} . ":"
      . $Shoze->Config->irc->{servers}->[0]->{port};
    LOG("* IRC server: $server");
    $irc->yield( register => 'all' );
    $irc->yield( connect =>
          { Server => $Shoze->Config->irc->{servers}->[0]->{host} } );
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
    DEBUG( join( ' ', @output ), 1 );
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

1;
