package App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Sessions;

use strict;
use warnings;

use Carp;

use POE;
use POE::Component::IRC::Plugin qw(:ALL);
use IRC::Utils qw(:ALL);

use Data::Dumper;

use lib qw(../../../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::Db::NetworkSessions::Object;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Helper qw(_get_nick)
  ;    # Must move BotCmd::Helper in Db
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
        qw(msg public ctcp_ping nick connected) );
    $self->irc($irc);
    return 1;
}

sub PCI_unregister {
    my ( $self, $irc ) = splice @_, 0, 2;
    return 1;
}

sub S_connected {
    my ( $self, $irc ) = splice @_, 0, 2;
    my $db      = App::IRC::Bot::Shoze::Db->new;
    my $Network = $irc->{Network};
    App::IRC::Bot::Shoze::Db->new->NetworkChannels->clear_joined($Network);
    return PCI_EAT_NONE;
}

sub destroy_session {
    my ( $self, $irc ) = splice @_, 0, 2;
    my ( $who, $msg ) = ( ${ $_[0] }, ${ $_[1] } );
    my $db = App::IRC::Bot::Shoze::Db->new;

    my $OldSession =
      App::IRC::Bot::Shoze::Db::NetworkSessions::Object->new($db)
      ->parse_who($who);
    my $NewSession = $db->Sessions->get_by(
        {
            nick     => $OldSession->nick,
            user     => $OldSession->user,
            hostname => $OldSession->hostname
        }
    );
    $db->Sessions->delete( $NewSession->id );
}

sub S_nick {
    my ( $self, $irc ) = splice @_, 0, 2;
    my ( $who, $msg ) = ( ${ $_[0] }, ${ $_[1] } );
    my $db = App::IRC::Bot::Shoze::Db->new;
    my $OldSession =
      App::IRC::Bot::Shoze::Db::NetworkSessions::Object->new($db)
      ->parse_who($who);
    my $NewSession = $db->Sessions->get_by(
        {
            user     => $OldSession->user,
            hostname => $OldSession->hostname
        }
    );
    $NewSession->nick($msg);
    $db->Sessions->update($NewSession);
}

sub _default {
    my ( $s, $irc, $event ) = splice @_, 0, 3;
    my $db = App::IRC::Bot::Shoze::Db->new;

    LOG( __PACKAGE__ . "  $event" );
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );

    $db->NetworkSessions->delete_idle;

    my ( $nick, $user, $hostname ) = parse_user($who);
    my $Nick = $s->_get_nick( $irc, $db, $irc->{Network}, $nick );
    unless ($Nick) {
        WARN( "Could not create nick '" . $Nick->nick . "'" );
        return PCI_EAT_NONE;
    }
    my $Session = $db->NetworkSessions->get_by(
        $Nick,
        {
            user     => $user,
            hostname => $hostname
        }
    );
    unless ( defined $Session ) {
        LOG("Creating session for $who");
        $db->NetworkSessions->create( $Nick, $user, $hostname );
    }
    else {
        LOG("Updating session");
        $db->NetworkSessions->update($Session);
        if ( $Session->ignore ) {
            LOG( "Ignoring " . $Session->_pretty );
            return PCI_EAT_ALL;
        }
    }
    return PCI_EAT_NONE;
}

1;
