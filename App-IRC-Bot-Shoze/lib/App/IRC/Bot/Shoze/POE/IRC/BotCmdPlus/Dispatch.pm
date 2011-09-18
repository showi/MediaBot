package App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Dispatch;

use strict;
use warnings;

use Carp;

use POE;
use POE::Component::IRC::Plugin qw(:ALL);
use IRC::Utils qw(:ALL);
#use Data::Dumper;

use lib qw(../../../../../../../);
use App::IRC::Bot::Shoze::Class qw(DESTROY);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::String;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Helper qw(_get_nick);

our %fields = ( cmd => undef, );

sub new {
    my ( $proto, $parent ) = @_;
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    return $s;
}

sub PCI_register {
    my ( $self, $irc ) = splice @_, 0, 2;

    # We store a ref to the $irc object so we can use it in our
    # session handlers.
    $self->{irc} = $irc;

    $irc->plugin_register( $self, 'SERVER', qw(msg public) );

    POE::Session->create( object_states => [ $self => [qw(_start _shutdown)], ],
    );

    return 1;
}

sub PCI_unregister {
    my ( $self, $irc ) = splice @_, 0, 2;

    # Plugin is dying make sure our POE session does as well.
    $poe_kernel->call( $self->{SESSION_ID} => '_shutdown' );
    delete $self->{irc};
    return 1;
}

sub _start {
    my ( $kernel, $self ) = @_[ KERNEL, OBJECT ];
    $self->{SESSION_ID} = $_[SESSION]->ID();

# Make sure our POE session stays around. Could use aliases but that is so messy :)
    $kernel->refcount_increment( $self->{SESSION_ID}, __PACKAGE__ );
    return;
}

sub _shutdown {
    my ( $kernel, $self ) = @_[ KERNEL, OBJECT ];
    $kernel->alarm_remove_all();
    $kernel->refcount_decrement( $self->{SESSION_ID}, __PACKAGE__ );
    return;
}

sub _default {
    my ( $s, $irc, $event ) = splice @_, 0, 3;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
   
    LOG("Dispatcher[$event]");
    LOG("Message: '$msg'");
     
    my $Config = App::IRC::Bot::Shoze::Config->new;
    my $prefix = $Config->bot->{cmd_prefix};
    
    my ($cmd, $cmd_args);
    if ($event eq "S_msg") {
        $msg =~ /^($prefix)?([\w\d][\w\d._-]*)(\s+(.*))?$/ or do {
          LOG("Not a command");
          return PCI_EAT_NONE;
        };   
        ( $cmd, $cmd_args ) = ( $2, str_chomp($3) );
    } else {
        $msg =~ /^$prefix([\w\d][\w\d._-]*)(\s+(.*))?$/ or do {
          LOG("Message not prefixed by '$prefix' so it's not a command");
          return PCI_EAT_NONE;
        };  
        ( $cmd, $cmd_args ) = ( $1, str_chomp($2) );      
    }
    $cmd =~ s/\./_/g;
    LOG("Got a command: $cmd [$cmd_args]");
    my $Master = $irc->plugin_get("BotCmdPlus");
    unless ( defined $Master->cmd->{$cmd} ) {
        LOG("No plugin have registered command '$cmd'");
        return PCI_EAT_NONE;
    }
    my $access = $Master->cmd->{$cmd}->{access};
    my $pat    = qr/^(S|U)_$access$/;
    unless ( $event =~ /$pat/ ) {
        LOG("Plugin not responding on $event '$cmd'");
        return PCI_EAT_NONE;
    }  
    my $db = App::IRC::Bot::Shoze::Db->new;
    my $Network = $irc->{Network} 
        or croak "No registered Network object within irc session";
    
    my ($nick, $user, $hostname) = parse_user($who);
    my $Nick = $s->_get_nick($db, $Network, $nick);
    unless($Nick) {
        WARN("Cannot create nick '$nick' for network " . $Network->name);
        return PCI_EAT_NONE;
    }
#    my $Session =
#      $db->Sessions->get_by( $Nick, { user => $user, hostname => $hostname });
#    unless ($Session) {
#        $irc->yield( privmsg => $nick => "# Who are you!" );
#        return PCI_EAT_ALL;
#    }
#    my $User;
#    if ( $Session->user_id ) {
#        $User = $db->Users->get_by( {id  => $Session->user_id } );
#    }
    my $Session = $db->NetworkSessions->get_extended($Network, $nick, $user, $hostname);
    unless($Session) {
        WARN("Cannot get session for $nick, $user, $hostname");
        return PCI_EAT_NONE;
    }
    $Session->last_access(time);
    $Session->_update();
    my $User;
    if ( $Session->user_id ) {
        $User = $db->Users->get_by( {id  => $Session->user_id } );
    }
    #LOG($Session->_pretty);
    my $pl  = $Master->cmd->{$cmd}->{plugin};
    my $lvl = $Master->cmd->{$cmd}->{lvl};
    if ( $lvl > 0 ) {
        unless ($Session->user_name) {
            $irc->yield( notice => $Session->nick =>
                  "You must be logged to execute this command" );
            return PCI_EAT_ALL;
        }
        if ( $Session->user_lvl < $lvl ) {
            $irc->yield( notice => $Session->nick =>
                  "You don't have the right to execute this command" );
            return PCI_EAT_ALL;
        }
    }
    LOG("Calling $cmd on plugin $pl");
    #$pl->$cmd( $Session, $User, $irc, $event, @_ );
    $pl->$cmd( $Session, $irc, $event, @_ );
    LOG($Session->_pretty);
    return PCI_EAT_ALL;
}

1;
