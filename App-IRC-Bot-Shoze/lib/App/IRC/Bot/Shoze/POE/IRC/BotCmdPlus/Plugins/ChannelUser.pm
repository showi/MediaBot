package App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::ChannelUser;

use strict;
use warnings;

use Carp;

use POE::Component::IRC::Plugin qw(:ALL);
use IRC::Utils qw(:ALL);

use lib qw(../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::String;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Helper;
use App::IRC::Bot::Shoze::Db::ChannelUsers::Object;

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
            'chanuser_add' => {
                access   => 'msg',
                lvl      => 500,
                help_cmd => '!chanuser.add <channel name> <user name> [lvl]',
                help_description => 'Link user to a given channel',
            },
            'chanuser_list' => {
                access   => 'msg',
                lvl      => 500,
                help_cmd => '!chanuser.list <channel name>',
                help_description =>
                  'Listing user\'s linked to a particular channel',
            },
        }
    );
    return $s;
}

sub chanuser_add {
    my ( $s, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'chanuser_add';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = $irc->{database};

    $msg = str_chomp($msg);
    my ( $cmd, $chan, $uname, $lvl ) = split /\s+/, $msg;
    LOG("$cmdname: $chan $uname $lvl");
    unless ( is_valid_chan_name($chan) ) {
        $s->_n_error( $irc, $Session->nick, "Invalid channel name '$chan'" );
        return PCI_EAT_ALL;
    }
    my $Channel = $db->Channels->get_by($chan);
    unless ($Channel) {
        $s->_n_error( $irc, $Session->nick, "Channel '$chan' not found" );
        return PCI_EAT_ALL;
    }
    if ( ( $Channel->owner != $User->id ) or ( $User->lvl < 800 ) ) {
        $s->_n_error( $irc, $Session->nick,
            "You can't add user to channel '$chan'" );
        return PCI_EAT_ALL;
    }
    unless ( $uname =~ /^[\w\d_-]+/ ) {
        $s->_n_error( $irc, $Session->nick, "Invalid user name '$uname'" );
        return PCI_EAT_ALL;
    }
    my $TUser = $db->Users->get_by( { name => $uname } );
    unless ($TUser) {
        $s->_n_error( $irc, $Session->nick, "User $uname not found" );
        return PCI_EAT_ALL;
    }
    my $ChannelUser = $db->ChannelUsers->get_by(
        { channel_id => $Channel->id, user_id => $TUser->id } );
    if ($ChannelUser) {
        $s->_n_error( $irc, $Session->nick,
            "User already linked to channel '$chan'" );
        return PCI_EAT_ALL;
    }

    $ChannelUser = new App::IRC::Bot::Shoze::Db::ChannelUsers::Object($db);
    $ChannelUser->channel_id( $Channel->id );
    $ChannelUser->user_id( $TUser->id );
    my $setlvl = $lvl || 200;
    if ( $lvl >= 500 ) { $setlvl = 200; }
    if ( $Channel->owner == $TUser->id ) {
        $setlvl = 500;
    }
    $ChannelUser->lvl($setlvl);
    $ChannelUser->created_on(time);
    unless ( $ChannelUser->_create ) {
        $s->_n_error( $irc, $Session->nick,
            "Cannot link user '$uname' to channel '$chan'" );
    }
    else {
        $irc->yield( notice => $Session->nick =>
              "User '$uname' linked to channel '$chan' with lelve $setlvl" );
    }
    return PCI_EAT_ALL;
}

sub chanuser_list {
    my ( $s, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'chanuser_add';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = $irc->{database};

    $msg = str_chomp($msg);
    my ( $cmd, $chan, $uname, $lvl ) = split /\s+/, $msg;
    LOG("$cmdname: $chan $uname $lvl");
    unless ( is_valid_chan_name($chan) ) {
        $s->_n_error( $irc, $Session->nick, "Invalid channel name '$chan'" );
        return PCI_EAT_ALL;
    }
    my $Channel = $db->Channels->get_by($chan);
    unless ($Channel) {
        $s->_n_error( $irc, $Session->nick, "Channel '$chan' not found" );
        return PCI_EAT_ALL;
    }
    if ( ( $Channel->owner != $User->id ) or ( $User->lvl < 800 ) ) {
        $s->_n_error( $irc, $Session->nick,
            "You can't list user linked to channel '$chan'" );
        return PCI_EAT_ALL;
    }
    my @list = $db->ChannelUsers->list();
    unless (@list) {
        $s->_n_error( $irc, $Session->nick, "No user linked to '$chan'" );
        return PCI_EAT_ALL;
    }
    my $str = "Listing user linked to $chan\n";
    for (@list) {
        $str .= "["
          . BOTLVL( $_->user_lvl )
          . "] name: "
          . $_->user_name
          . ", lvl: "
          . $_->lvl;
        $str .= ", auto_mode: " . $_->auto_mode if $_->auto_mode;
        $str .= "\n";
    }
    $s->_send_lines( $irc, 'notice', $Session->nick, split( /\n/, $str ) );
    return PCI_EAT_ALL;
}

1;
