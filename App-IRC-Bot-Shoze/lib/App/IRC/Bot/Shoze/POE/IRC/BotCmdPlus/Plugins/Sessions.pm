package App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::Sessions;

use strict;
use warnings;

use Carp;

use POE;
use POE::Component::IRC::Plugin qw(:ALL);
use IRC::Utils qw(:ALL);

use Data::Dumper;

use lib qw(../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::Db::Sessions::Object;

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
    $irc->plugin_register( $self, 'SERVER',
        qw(msg public ctcp_ping nick connected)
    );
    $self->irc($irc);
    return 1;
}

sub PCI_unregister {
    my ( $self, $irc ) = splice @_, 0, 2;
    return 1;
}


sub S_connected {
    my ( $self, $irc ) = splice @_, 0, 2;
    $irc->{database}->Channels->clear_joined;
    $irc->yield( 'mode' => $irc->nick_name => '+x' );
    return PCI_EAT_NONE;
}



sub destroy_session {
    my ( $self, $irc ) = splice @_, 0, 2;
    my ( $who, $msg ) = ( ${ $_[0] }, ${ $_[1] } );
    my $db         = $irc->{database};

    my $OldSession = App::IRC::Bot::Shoze::Db::Sessions::Object->new($db)->parse_who($who);
    my $NewSession =
      $db->Sessions->get( $OldSession->nick, $OldSession->user,
        $OldSession->hostname );
    $db->Sessions->delete( $NewSession->id );
}

sub S_nick {
    my ( $self, $irc ) = splice @_, 0, 2;
    my ( $who, $msg ) = ( ${ $_[0] }, ${ $_[1] } );
    my $db         = $irc->{database};
    my $OldSession = App::IRC::Bot::Shoze::Db::Sessions::Object->new($db)->parse_who($who);
    my $NewSession =
      $db->Sessions->get_by_user_hostname( $OldSession->user,
        $OldSession->hostname );
    $NewSession->nick($msg);
    $db->Sessions->update($NewSession);
}

sub _default {
    my ( $self, $irc, $event ) = splice @_, 0, 3;

    # my $dump = Data::Dumper->new( [$irc] );
    my $db = $irc->{database};
    LOG( '-' x 80 );
    LOG( __PACKAGE__ . " Unprocessed event: $event" );
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    $db->Sessions->delete_idle;
    my $TmpSession = App::IRC::Bot::Shoze::Db::Sessions::Object->new($db)->parse_who($who);

    my $Session =
      $db->Sessions->get( $TmpSession->nick, $TmpSession->user,
        $TmpSession->hostname );
    unless ( defined $Session ) {
        LOG( "Creating session: " . $TmpSession->_pretty );
        $db->Sessions->create( $TmpSession->nick, $TmpSession->user,
            $TmpSession->hostname );

        #$Session = $db->Sessions->get( $Session->user, $Session->hostname );
    }
    else {
        LOG("Updating session");
        $db->Sessions->update($Session);
        if ( $Session->ignore ) {
            LOG( "Ignoring " . $Session->pretty );
#            $irc->yield( notice => $Session->nick =>
#                  "You re boring... keep quiet please!" );
            return PCI_EAT_ALL;
        }
    }
    LOG( __PACKAGE__ . " is dispatchin $event" );
    return PCI_EAT_NONE;
}

1;
