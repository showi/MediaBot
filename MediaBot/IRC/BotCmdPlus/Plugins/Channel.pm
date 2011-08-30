package MediaBot::IRC::BotCmdPlus::Plugins::Channel;

use strict;
use warnings;

use Carp;

use POE::Component::IRC::Plugin qw(:ALL);

use lib qw(../../../../);
use MediaBot::Class qw(AUTOLOAD);
use MediaBot::Log;
use MediaBot::String;
use MediaBot::IRC::BotCmdPlus::Helper;

our %fields = ( cmd => undef );

sub new {
    my ( $proto, $parent ) = @_;
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    $s->cmd(
        {
            'channel_add' => {
                access   => 'msg',
                lvl      => 800,
                help_cmd => '!channel.add [#|&]channel_name',
                help_description =>
'Adding channel. You must be admin or owner of the bot (>800)',
            },
            'channel_list' => {
                access   => 'msg',
                lvl      => 800,
                help_cmd => '!channel.list',
                help_description =>
'Listing channel. you must be admin or owner of the bot (>800)',
            },
            'channel_user_set_owner' => {
                access   => 'msg',
                lvl      => 800,
                help_cmd => '!channel.user.set_owner [#|&]channel_name name',
                help_description =>
'Listing channel. you must be admin or owner of the bot (>800)',
            },
        }
    );
    return $s;
}

sub channel_add {
    my ( $self, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'channel_add';
    my $PCMD    = $self->get_cmd($cmdname);
    my $db      = $irc->{database};

    unless ( $Session->user_id ) {
        $irc->yield(
            notice => $Session->nick => "[$cmdname] You must be logged!" );
        return PCI_EAT_ALL;
    }
    if ( $User->lvl < $PCMD->{lvl} ) {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] You don't have the right to add channel!" );
        return PCI_EAT_ALL;
    }
    my ($channame) = ( split( /\s+/, $msg ) )[1];
    $channame =~ /^(#|&)([\w\d_]+)$/ or do {
        $irc->yield( notice => $Session->nick => "[$cmdname] Invalid syntax, "
              . $self->pretty_help($cmdname) );
        return PCI_EAT_ALL;
    };
    my $type;
    ( $type, $channame ) = ( $1, $2 );
    my $Channel = $db->Channels->get( $type, $channame );
    if ($Channel) {
        $irc->yield( notice => $Session->nick => "[$cmdname] Channel '"
              . $Channel->usable_name
              . "' already exist!" );
        return PCI_EAT_ALL;
    }
    LOG("Creating channel '$channame'");
    $Channel = $db->Channels->create( $type, $channame, $User->id );
    if ($Channel) {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] Channel $type$channame created." );
    }
    else {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] Cannot create channel $type$channame" );
    }
    return PCI_EAT_ALL;
}

sub channel_list {
    my ( $self, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'channel_list';
    my $PCMD    = $self->get_cmd($cmdname);
    my $db      = $irc->{database};

    unless ( $Session->user_id ) {
        $irc->yield(
            notice => $Session->nick => "[$cmdname] You must be logged!" );
        return PCI_EAT_ALL;
    }
    if ( $User->lvl < $PCMD->{lvl} ) {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] You don't have the right to list channel!" );
        return PCI_EAT_ALL;
    }

    my @list = $db->Channels->list;
    unless (@list) {
        $irc->yield(
            notice => $Session->nick => "[$cmdname] No channel in database " );
        return PCI_EAT_ALL;
    }
    $irc->yield( notice => $Session->nick => "[$cmdname] Listing channel " );
    for (@list) {
        my $str = " -" . $_->usable_name;
        $str .= " (" . localtime( int $_->created_on ) . ")";
        $irc->yield( notice => $Session->nick => $str );
    }
    return PCI_EAT_ALL;
}

sub channel_user_set_owner {
    my ( $self, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'channel_user_set_owner';
    my $PCMD    = $self->get_cmd($cmdname);
    my $db      = $irc->{database};
    unless ( $Session->user_id ) {
        $irc->yield(
            notice => $Session->nick => "[$cmdname] You must be logged!" );
        return PCI_EAT_ALL;
    }
    if ( $User->lvl < $PCMD->{lvl} ) {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] You don't have the right to list channel!" );
        return PCI_EAT_ALL;
    }
    LOG("msg: $msg");
    my ( $channame, $name ) = ( split( /\s+/, $msg ) )[ 1 .. 2 ];
    $channame =~ /^(#|&)([\w\d_-]+)$/ or do {
        $irc->yield(
            notice => $Session->nick => "[$cmdname] Invalid channel name, "
              . $self->pretty_help($cmdname) );
        return PCI_EAT_ALL;
    };
    my $type;
    ( $type, $channame ) = ( $1, $2 );
    $name =~ /^[\w\d_-]+$/ or do {
        $irc->yield(
            notice => $Session->nick =>
              "[$cmdname] Invalid user name, "
              . $self->pretty_help($cmdname)
        );
        return PCI_EAT_ALL;
    };
    my $Channel = $db->Channels->get( $type, $channame );
    unless ($Channel) {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] No channel named '$type$channame'" );
        return PCI_EAT_ALL;
    }
    my $Owner = $db->Users->get_byname($name);
    unless ($Owner) {
        $irc->yield(
            notice => $Session->nick => "[$cmdname] No user named '$name'" );
        return PCI_EAT_ALL;
    }
    if ( $db->Channels->set( $Channel->id, 'owner', $Owner->id ) ) {
        $irc->yield( notice => $Session->nick => "[$cmdname] "
              . $Channel->usable_name
              . " owner set to "
              . $Owner->name );
        return PCI_EAT_ALL;
    }
    else {
        $irc->yield( notice => $Session->nick => "[$cmdname] Cannot set "
              . $Channel->usable_name
              . " owner set to "
              . $Owner->name );
        return PCI_EAT_ALL;
    }

}
1;
