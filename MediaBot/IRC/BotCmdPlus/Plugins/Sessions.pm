package MediaBot::IRC::BotCmdPlus::Plugins::Sessions;

use strict;
use warnings;

use Carp;

use POE;
use POE::Component::IRC::Plugin qw(:ALL);

use Data::Dumper;

use lib qw(../../../../);
use MediaBot::Class qw(AUTOLOAD);
use MediaBot::Log;
use MediaBot::Db::Sessions::Object;

our %fields = ( cmd => undef, irc => undef );

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
    $irc->plugin_register( $self, 'SERVER', qw(msg public ctcp_ping) );
    $self->irc($irc);
    return 1;
}

sub PCI_unregister {
    my ( $self, $irc ) = splice @_, 0, 2;
    return 1;
}

sub _default {
    my ( $self, $irc, $event ) = splice @_, 0, 3;
    my $dump = Data::Dumper->new( [$irc] );
    my $db = $irc->{database};
    LOG('-'x80);
    LOG(__PACKAGE__ . " Unprocessed event: $event");
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    $db->Sessions->delete_idle;
    my $TmpSession = MediaBot::Db::Sessions::Object->new()->parse_who($who);

    my $Session =
      $db->Sessions->get( $TmpSession->nick, $TmpSession->user, $TmpSession->hostname );
    unless ( defined $Session ) {
        LOG( "Creating session: " . $TmpSession->pretty );
        $db->Sessions->create( $TmpSession->nick, $TmpSession->user,
            $TmpSession->hostname );
        #$Session = $db->Sessions->get( $Session->user, $Session->hostname );
    } else {
        LOG("Updating session");
        $db->Sessions->update($Session);
        if ( $Session->ignore ) {
            LOG( "Ignoring " . $Session->pretty );
            $irc->yield( notice => $Session->nick =>
                  "You re boring... keep quiet please!" );
            return PCI_EAT_ALL;
        }
    }
    LOG( __PACKAGE__ . " is dispatchin $event" );
    return PCI_EAT_NONE;
}

1;
