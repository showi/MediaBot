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
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Helper qw(:ALL);
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
            'chanuser_del' => {
                access   => 'msg',
                lvl      => 500,
                help_cmd => '!chanuser.del <channel name> <user>',
                help_description =>
                  'Remove a linked user from a specified channel',
            },
            'chanuser_set' => {
                access => 'msg',
                lvl    => 500,
                help_cmd =>
                  '!chanuser.set <channel name> <user> <lvl|auto_mode> <value>',
                help_description =>
                  'Remove a linked user from a specified channel',
            },
            'chanuser_info' => {
                access           => 'msg',
                lvl              => 500,
                help_cmd         => '!chanuser.set <channel name> <user>',
                help_description => 'Get channel user information',
            },
        }
    );
    return $s;
}

###############################################################################
sub chanuser_add {
    my ( $s, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'chanuser_add';
    my $PCMD    = $s->get_cmd($cmdname);
     my $db = App::IRC::Bot::Shoze::Db->new;

    $msg = str_chomp($msg);
    my ( $cmd, $chan, $uname, $lvl ) = split /\s+/, $msg;
    LOG("$cmdname: $chan $uname $lvl");
    unless ( is_valid_chan_name($chan) ) {
        return $s->_n_error( $irc, $Session->nick,
            "Invalid channel name '$chan'" );
    }
    my ($type, $channame) = ($chan =~ /^(#|&)(.*)$/);
    my $Channel = $db->Channels->get_by({ type => $type, name => $channame });
    unless ($Channel) {
        return $s->_n_error( $irc, $Session->nick,
            "Channel '$chan' not found" );
    }
    if ( ( $Channel->owner != $User->id ) or ( $User->lvl < 800 ) ) {
        return $s->_n_error( $irc, $Session->nick,
            "You can't add user to channel '$chan'" );
    }
    unless ( $uname =~ /^[\w\d_-]+/ ) {
        return $s->_n_error( $irc, $Session->nick,
            "Invalid user name '$uname'" );
    }
    my $TUser = $db->Users->get_by( { name => $uname } );
    unless ($TUser) {
        return $s->_n_error( $irc, $Session->nick, "User $uname not found" );
    }
    my $ChannelUser = $db->ChannelUsers->get_by(
        { channel_id => $Channel->id, user_id => $TUser->id } );
    if ($ChannelUser) {
        return $s->_n_error( $irc, $Session->nick,
            "User already linked to channel '$chan'" );
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
        return $s->_n_error( $irc, $Session->nick,
            "Cannot link user '$uname' to channel '$chan'" );
    }
    else {
        $irc->yield( notice => $Session->nick =>
              "User '$uname' linked to channel '$chan' with lelve $setlvl" );
    }
    return PCI_EAT_ALL;
}

###############################################################################
sub chanuser_set {
    my ( $s, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'chanuser_set';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db = App::IRC::Bot::Shoze::Db->new;

    $msg = str_chomp($msg);
    my ( $cmd, $chan, $uname, $key, $value ) = split /\s+/, $msg;
    LOG("$cmdname: $chan $uname $key $value");
    my @authkeys = qw(lvl auto_mode);

    unless ( grep $key, @authkeys ) {
        return $s->_n_error( $irc, $Session->nick, "Invalid keys '$key'" );
    }
    unless ( is_valid_chan_name($chan) ) {
        return $s->_n_error( $irc, $Session->nick,
            "Invalid channel name '$chan'" );
    }
    my ($type, $channame) = ($chan =~ /^(#|&)(.*)$/);
    my $Channel = $db->Channels->get_by({ type => $type, name => $channame });
    unless ($Channel) {
        return $s->_n_error( $irc, $Session->nick,
            "Channel '$chan' not found" );
    }
    if ( ( $Channel->owner != $User->id ) or ( $User->lvl < 800 ) ) {
        return $s->_n_error( $irc, $Session->nick,
            "You can't set key '$key' to channel '$chan'" );
    }
    my $TUser = $db->Users->get_by( { name => $uname } );
    unless ($TUser) {
        return $s->_n_error( $irc, $Session->nick, "Unknow user '$uname'" );
    }
    my $MeChanUser = $db->ChannelUsers->get_by(
        { channel_id => $Channel->id, user_id => $User->id } );
    my $TChanUser = $db->ChannelUsers->get_by(
        { channel_id => $Channel->id, user_id => $TUser->id } );
    if ( $key eq "lvl" ) {
        $value = int($value);
        if ( $value >= $MeChanUser->lvl ) {
            return $s->_n_error( $irc, $Session->nick,
                "Cannot set lvl greater than yours" );
        }
        elsif ( $value < 0 ) {
            return $s->_n_error( $irc, $Session->nick,
                "Cannot set negative lvl" );
        }
    }
    elsif ( $key eq "auto_mode" ) {
        unless ( $key =~ /^(o|v)$/ ) {
            return $s->_n_error( $irc, $Session->nick,
                "Invalid $key value '$value must be 'o' or 'v'" );
        }
    }
    else {
        return $s->_n_error( $irc, $Session->nick, "Unknown option $key" );
    }
    $TChanUser->$key($value);
    unless (
        $TChanUser->_update_by(
            { channel_id => $Channel->id, user_id => $TUser->id }
        )
      )
    {
        return $s->_n_error( $irc, $Session->nick,
            "Cannot set '$key' to '$value'" );
    }
    else {
        $irc->yield(
            notice => $Session->nick => "$key as been set to '$value'" );
    }
    return PCI_EAT_ALL;
}

###############################################################################
sub chanuser_list {
    my ( $s, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'chanuser_list';
    my $PCMD    = $s->get_cmd($cmdname);
     my $db = App::IRC::Bot::Shoze::Db->new;

    $msg = str_chomp($msg);
    my ( $cmd, $chan, $uname, $lvl ) = split /\s+/, $msg;
    LOG("$cmdname: $chan $uname $lvl");
    unless ( is_valid_chan_name($chan) ) {
        return $s->_n_error( $irc, $Session->nick,
            "Invalid channel name '$chan'" );
    }
    my ($type, $channame) = ($chan =~ /^(#|&)(.*)$/);
    my $Channel = $db->Channels->get_by({ type => $type, name => $channame });
    unless ($Channel) {
        return $s->_n_error( $irc, $Session->nick,
            "Channel '$chan' not found" );
    }
    if ( ( $Channel->owner != $User->id ) or ( $User->lvl < 800 ) ) {
        return $s->_n_error( $irc, $Session->nick,
            "You can't list user linked to channel '$chan'" );
    }
    my @list = $db->ChannelUsers->list();
    unless (@list) {
        return $s->_n_error( $irc, $Session->nick,
            "No user linked to '$chan'" );
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

###############################################################################
sub chanuser_info {
    my ( $s, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'chanuser_info';
    my $PCMD    = $s->get_cmd($cmdname);
     my $db = App::IRC::Bot::Shoze::Db->new;

    $msg = str_chomp($msg);
    my ( $cmd, $chan, $uname ) = split /\s+/, $msg;
    LOG("$cmdname: $chan $uname");
    unless ( is_valid_chan_name($chan) ) {
        return $s->_n_error( $irc, $Session->nick,
            "Invalid channel name '$chan'" );
    }
    my ($type, $channame) = ($chan =~ /^(#|&)(.*)$/);
    my $Channel = $db->Channels->get_by({ type => $type, name => $channame });
    unless ($Channel) {
        return $s->_n_error( $irc, $Session->nick,
            "Channel '$chan' not found" );
    }
    if ( ( $Channel->owner != $User->id ) or ( $User->lvl < 800 ) ) {
        return $s->_n_error( $irc, $Session->nick,
            "You can't get information on user '$uname' for channel '$chan'" );
    }
    my $TUser = $db->Users->get_by( { name => $uname } );
    unless ($TUser) {
        return $s->_n_error( $irc, $Session->nick,
            "Could not find user named '$uname'" );
    }
    my $UserChannel = $db->ChannelUsers->get_by(
        { channel_id => $Channel->id, user_id => $TUser->id } );
    unless ($UserChannel) {
        return $s->_n_error( $irc, $Session->nick,
            "User 'uname' is not linked to channel '$chan'" );
    }
    my $str .= "[" . BOTLVL( $TUser->lvl )
      . "] name: " . $TUser->name . ", lvl: " . $UserChannel->lvl;
    $str .= ", auto_mode: " . $UserChannel->auto_mode
      if $UserChannel->auto_mode;
    $irc->yield( 'notice' => $Session->nick => $str );
    return PCI_EAT_ALL;
}

###############################################################################
sub chanuser_del {
    my ( $s, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'chanuser_del';
    my $PCMD    = $s->get_cmd($cmdname);
     my $db = App::IRC::Bot::Shoze::Db->new;

    $msg = str_chomp($msg);
    my ( $cmd, $chan, $uname ) = split /\s+/, $msg;
    LOG("$cmdname: $chan $uname");
    unless ( is_valid_chan_name($chan) ) {
        return $s->_n_error( $irc, $Session->nick,
            "Invalid channel name '$chan'" );
    }
    my ($type, $channame) = ($chan =~ /^(#|&)(.*)$/);
    my $Channel = $db->Channels->get_by($chan);
    unless ($Channel) {
        return $s->_n_error( $irc, $Session->nick,
            "Channel '$chan' not found" );
    }
    if ( ( $Channel->owner != $User->id ) or ( $User->lvl < 800 ) ) {
        return $s->_n_error( $irc, $Session->nick,
            "You can't delete user linked to channel '$chan'" );
    }
    my $TUser = $db->Users->get_by( { name => $uname } );
    unless ($TUser) {
        return $s->_n_error( $irc, $Session->nick,
            "Could not find user named '$uname'" );
    }
    my $UserChannel = $db->ChannelUsers->get_by(
        { channel_id => $Channel->id, user_id => $TUser->id } );
    unless ($UserChannel) {
        return $s->_n_error( $irc, $Session->nick,
            "User 'uname' is not linked to channel '$chan'" );
    }
    unless (
        $UserChannel->_delete_by(
            { channel_id => $Channel->id, user_id => $TUser->id }
        )
      )
    {
        return $s->_n_error( $irc, $Session->nick,
            "Could not delete ling between channel '$chan' and user '$uname'" );
    }
    else {
        $irc->yield( notice => $Session->nick =>
              "User '$uname' unlinked from channel '$chan'" );
    }
    return PCI_EAT_ALL;
}
###############################################################################

1;
