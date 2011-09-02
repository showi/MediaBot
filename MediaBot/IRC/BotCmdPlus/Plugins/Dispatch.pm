package MediaBot::IRC::BotCmdPlus::Plugins::Dispatch;

use strict;
use warnings;

use Carp;

use POE;
use POE::Component::IRC::Plugin qw(:ALL);

#use Data::Dumper;

use lib qw(../../../../);
use MediaBot::Class qw(DESTROY);
use MediaBot::Log;
use MediaBot::String;

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
     my ($self, $irc) = splice @_, 0, 2;

     # We store a ref to the $irc object so we can use it in our
     # session handlers.
     $self->{irc} = $irc;

     $irc->plugin_register( $self, 'SERVER', qw(msg public) );

     POE::Session->create(
         object_states => [
             $self => [qw(_start _shutdown)],
         ],
     );

     return 1;
 }

 sub PCI_unregister {
     my ($self, $irc) = splice @_, 0, 2;
     # Plugin is dying make sure our POE session does as well.
     $poe_kernel->call( $self->{SESSION_ID} => '_shutdown' );
     delete $self->{irc};
     return 1;
 }

 sub _start {
     my ($kernel, $self) = @_[KERNEL, OBJECT];
     $self->{SESSION_ID} = $_[SESSION]->ID();
     # Make sure our POE session stays around. Could use aliases but that is so messy :)
     $kernel->refcount_increment( $self->{SESSION_ID}, __PACKAGE__ );
     return;
 }

 sub _shutdown {
     my ($kernel, $self) = @_[KERNEL, OBJECT];
     $kernel->alarm_remove_all();
     $kernel->refcount_decrement( $self->{SESSION_ID}, __PACKAGE__ );
     return;
 }

sub _default {
    my ( $self, $irc, $event ) = splice @_, 0, 3; 
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    LOG("Dispatcher[$event]");
    LOG("Message: '$msg'");
    $msg =~ /^!([\w\d][\w\d._-]*)(\s+(.*))?$/ or do {
        LOG("Message not prefixed by '!' so it's not a command");
        return PCI_EAT_NONE;
    };
    my ($cmd, $cmd_args) = ($1, str_chomp($2));
    $cmd =~ s/\./_/g;
    LOG("Got a command: $1 [$cmd_args]");
    my $Master = $irc->plugin_get("BotCmdPlus");
    unless (defined $Master->cmd->{$cmd}) {
        LOG("No plugin have registered command '$cmd'");
        return PCI_EAT_NONE;
    }
    my $access = $Master->cmd->{$cmd}->{access};
    my $pat = qr/^(S|U)_$access$/;
    unless($event =~ /$pat/) {
        LOG("Plugin not responding on $event '$cmd'");
        return PCI_EAT_NONE;
    }
      
    my $db         = $irc->{database};
    my $TmpSession = new MediaBot::Db::Sessions::Object();
    $TmpSession->parse_who( $who );
    my $Session =
      $db->Sessions->get( $TmpSession->nick, $TmpSession->user,
        $TmpSession->hostname );
    unless ($Session) {
        $irc->yield(
            privmsg => $TmpSession->nick => "# Who are you!" );
        return PCI_EAT_ALL;
    }
    my $User;
    if ( $Session->user_id ) {
        $User = $db->Users->get($Session->user_id);
    }
    #my $ev = "irc_BC_$event"."_$cmd";
    my $pl = $Master->cmd->{$cmd}->{plugin};
    LOG("Calling $cmd on plugin $pl");
    $pl->$cmd($Session, $User, $irc, $event, @_);
    #$poe_kernel->post($_[KERNEL] => 'irc_BC_version' => $cmd_args);
    return PCI_EAT_ALL;
}

1;
