package MediaBot::IRC::BotCmdPlus::Plugins::Sessions;

use strict;
use warnings;

use Carp;

use POE;
use POE::Component::IRC::Plugin qw(:ALL);
use IRC::Utils qw(:ALL);

use Data::Dumper;

use lib qw(../../../../);
use MediaBot::Class qw(AUTOLOAD DESTROY);
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
    $irc->plugin_register( $self, 'SERVER',
        qw(msg public ctcp_ping nick part connected join part invite 324 chanmode)
    );
    $self->irc($irc);
    return 1;
}

sub PCI_unregister {
    my ( $self, $irc ) = splice @_, 0, 2;
    return 1;
}

#sub S_chanmode {
#    my ( $self, $irc ) = splice @_, 0, 2;
#    my ( $who, $where ) = ( ${ $_[0] }, ${ $_[1] } );
#    LOG("Event[324] '$who', '$where '");
#    $where =~ /^([#|&][\w\d_-]+)\s+\+(([^\s]+)(\s+.*)?)?$/ and do {
#        my ( $chan, $mode, $args ) = ( $1, $3, $4 );
#
#        #$mode =~ s/[kl]//g;
#        LOG("Channel $1 have mode $2");
#        my $db      = $irc->{database};
#        my $Channel = $db->Channels->get_by_name($chan);
#        return PCI_EAT_NONE unless $Channel;
#        return PCI_EAT_NONE unless $Channel->auto_mode;
#        my $newmode = "+" . $Channel->mode;
#        my $newargs = "";
#
#                if ($Channel->password) {
#                   $newmode .= "k";
#                   $newargs .= $Channel->password . " ";
#                }
#                if ($Channel->ulimit) {
#                    $newmode.= "l";
#                    $newargs .= $Channel->ulimit. " ";
#                }
#        my $rmode = gen_mode_change( $mode, $newmode );
#        return PCI_EAT_NONE if ( ( $mode eq $rmode ) );
#        $irc->yield( 'mode' => $chan => $rmode => $newargs );
#
#    };
#    return PCI_EAT_ALL;
#}

sub S_324 {
    my ( $self, $irc ) = splice @_, 0, 2;
    my ( $who, $where ) = ( ${ $_[0] }, ${ $_[1] } );
    LOG("Event[324] '$who', '$where '");
    $where =~ /^([#|&][\w\d_-]+)\s+\+(([^\s]+)(\s+.*)?)?$/ and do {
        my ( $chan, $mode, $args ) = ( $1, $3, $4 );

        #$mode =~ s/[kl]//g;
        LOG("Channel $1 have mode $2");
        my $db      = $irc->{database};
        my $Channel = $db->Channels->get_by($chan);
        return PCI_EAT_NONE unless $Channel;
        return PCI_EAT_NONE unless $Channel->auto_mode;
        my $newmode = "+" . $Channel->mode;
        my $newargs = "";

                if ($Channel->password) {
                   $newmode .= "k";
                   $newargs .= $Channel->password . " ";
                }
#                if ($Channel->ulimit) {
#                    $newmode.= "l";
#                    $newargs .= $Channel->ulimit. " ";
#                }
        my $rmode = gen_mode_change( $mode, $newmode );
        LOG("MODE CHANGE $rmode / $newmode");
        return PCI_EAT_NONE if ( !$rmode or ( $mode eq $rmode ) );
        $irc->yield( 'mode' => $chan => $rmode => $newargs );

    };
    return PCI_EAT_ALL;
}

sub S_connected {
    my ( $self, $irc ) = splice @_, 0, 2;
    $irc->{database}->Channels->clear_joined;
    $irc->yield( 'mode' => $irc->nick_name => '+x' );
    return PCI_EAT_NONE;
}

sub S_invite {
    my ( $self, $irc ) = splice @_, 0, 2;
    my $db = $irc->{database};

    my ( $who, $where ) = ( ${ $_[0] }, ${ $_[1] } );
    my $Channel = $db->Channels->get_by_name($where);
    return PCI_EAT_NONE unless $Channel;
    LOG("We receive an invite on $where!");
    return PCI_EAT_NONE if $Channel->bot_joined;

    $irc->yield( 'join' => $where );
    return PCI_EAT_NONE;
}

sub S_join {
    my ( $self, $irc ) = splice @_, 0, 2;
    my ( $who, $where ) = ( ${ $_[0] }, ${ $_[1] } );
    my ( $nick, $user, $hostmask ) = parse_user($who);
    if ( $irc->nick_name eq $nick ) {
        my $db      = $irc->{database};
        my $Channel = $db->Channels->get_by($where);
        return PCI_EAT_NONE unless $Channel;
        $Channel->bot_joined(1);
        $Channel->bot_mode(undef);
        $Channel->_update;
        LOG("We have joined channel $where");
    }
    return PCI_EAT_NONE;
}

sub S_part {
    my ( $self, $irc ) = splice @_, 0, 2;
    my ( $who, $where ) = ( ${ $_[0] }, ${ $_[1] } );
    my ( $nick, $user, $hostmask ) = parse_user($who);
    my $db = $irc->{database};

    if ( $irc->nick_name eq $nick ) {
        $irc->{database}->Channels->bot_leave($where);
        LOG("We have leaved channel $where");
    }
    else {
        my $NewSession = $db->Sessions->get( $nick, $user, $hostmask );
        $db->Sessions->delete( $NewSession->id );
    }
    return PCI_EAT_NONE;
}

sub destroy_session {
    my ( $self, $irc ) = splice @_, 0, 2;
    my ( $who, $msg ) = ( ${ $_[0] }, ${ $_[1] } );
    my $db         = $irc->{database};
    my $OldSession = MediaBot::Db::Sessions::Object->new()->parse_who($who);
    my $NewSession =
      $db->Sessions->get( $OldSession->nick, $OldSession->user,
        $OldSession->hostname );
    $db->Sessions->delete( $NewSession->id );
}

sub S_nick {
    my ( $self, $irc ) = splice @_, 0, 2;
    my ( $who, $msg ) = ( ${ $_[0] }, ${ $_[1] } );
    my $db         = $irc->{database};
    my $OldSession = MediaBot::Db::Sessions::Object->new()->parse_who($who);
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
    my $TmpSession = MediaBot::Db::Sessions::Object->new()->parse_who($who);

    my $Session =
      $db->Sessions->get( $TmpSession->nick, $TmpSession->user,
        $TmpSession->hostname );
    unless ( defined $Session ) {
        LOG( "Creating session: " . $TmpSession->pretty );
        $db->Sessions->create( $TmpSession->nick, $TmpSession->user,
            $TmpSession->hostname );

        #$Session = $db->Sessions->get( $Session->user, $Session->hostname );
    }
    else {
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
