package App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::Channel;

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
                access           => 'msg',
                lvl              => 800,
                help_cmd         => '!channel.add <channel name>',
                help_description => 'Adding channel',
            },
            'channel_del' => {
                access           => 'msg',
                lvl              => 800,
                help_cmd         => '!channel.del <channel name>',
                help_description => 'Deleting channel',
            },
            'channel_info' => {
                access           => 'msg',
                lvl              => 500,
                help_cmd         => '!channel.info <channel name>',
                help_description => 'Adding channel',
            },
            'channel_set' => {
                access           => 'msg',
                lvl              => 500,
                help_cmd         => '!channel.set <key> <value>',
                help_description => 'Adding channel',
            },
            'channel_list' => {
                access           => 'msg',
                lvl              => 800,
                help_cmd         => '!channel.list',
                help_description => 'Listing channel.',
            },
            'channel_set_owner' => {
                access           => 'msg',
                lvl              => 800,
                help_cmd         => '!channel.set.owner <channel_name>',
                help_description => 'Setting channel owner',
            },
            'op' => {
                access           => 'public|msg',
                lvl              => 200,
                help_cmd         => '!op [channel list]',
                help_description => 'Give you op!',
            },
            'deop' => {
                access           => 'public|msg',
                lvl              => 200,
                help_cmd         => '!deop [channel list]',
                help_description => 'Deop you!',
            },
            'join' => {
                access           => 'public|msg',
                lvl              => 500,
                help_cmd         => '!join <channel list>',
                help_description => 'Make bot joining channel!',
            },
            'part' => {
                access           => 'public|msg',
                lvl              => 500,
                help_cmd         => '!part <channel list>',
                help_description => '!Make bot leaving channel',
            },
            'topic' => {
                access           => 'public|msg',
                lvl              => 500,
                help_cmd         => '!topic [channel] <topic>',
                help_description => '!set channel topic',
            }
        }
    );
    return $s;
}

sub channel_del {
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
              "[$cmdname] You don't have the right to delete channel!" );
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
    my $Channel = $db->Channels->get_by( $type, $channame );
    if ( !$Channel ) {
        $irc->yield(
            notice => $Session->nick => "[$cmdname] Channel doesn't exist!" );
        return PCI_EAT_ALL;
    }
    LOG("Deleting channel '$channame'");

    #$Channel = $db->Channels->create( $type, $channame, $User->id );
    if ( $Channel->_delete ) {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] Channel $type$channame deleted." );
        my $aj = $irc->plugin_get('AutoJoin');
        delete $aj->{Channels}->{"$type$channame"};
        $irc->yield( part => "$type$channame" );
    }
    else {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] Cannot delete channel $type$channame" );
    }
    return PCI_EAT_ALL;
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
    my $Channel = $db->Channels->get_by( $type, $channame );
    if ($Channel) {
        $irc->yield( notice => $Session->nick => "[$cmdname] Channel '"
              . $Channel->_usable_name
              . "' already exist!" );
        return PCI_EAT_ALL;
    }
    LOG("Creating channel '$channame'");
    $Channel = $db->Channels->create( $type, $channame, $User->id );
    if ($Channel) {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] Channel $type$channame created." );
        my $aj = $irc->plugin_get('AutoJoin');
        $aj->{Channels}->{"$type$channame"} = '';
        $irc->yield( join => "$type$channame" );
    }
    else {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] Cannot create channel $type$channame" );
    }
    return PCI_EAT_ALL;
}

sub channel_info {
    my ( $self, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'channel_info';
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
    print "msg: $msg\n";
    my $chan = ( split( /\s+/, $msg ) )[1];
    $chan =~ /^([#&])([^\s]+)/ or do {
        $irc->yield(
            notice => $Session->nick => "[$cmdname] Invalid channel name!" );
        return PCI_EAT_ALL;
    };
    my ( $type, $name ) = ( $1, $2 );
    unless ( is_valid_chan_name("$type$name") ) {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] Invalid channel name $type$name" );
        return PCI_EAT_ALL;
    }
    my $Channel = $db->Channels->get_by( $type, $name );
    unless ($Channel) {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] Channel $type$name not found!" );
        return PCI_EAT_ALL;
    }
    my $Owner;
    if ( $Channel->owner ) {
        $Owner = $db->Users->get( $Channel->owner );
    }
    my $out = "Channel information [$type$name] ";
    $out .= ( $Owner ? " (" . $Owner->name . ")\n" : "\n" );
    $out .= " - bot mode_____: "
      . ( $Channel->bot_mode ? "+" . $Channel->bot_mode : "" ) . "\n";
    $out .=
      " - auto mode____: " . ( $Channel->auto_mode ? "yes" : "no" ) . "\n";
    $out .= " - mode_________: "
      . ( $Channel->mode ? "+" . $Channel->mode : "" ) . "\n";
    $out .= " - password_____: "
      . ( $Channel->password ? $Channel->password : "" ) . "\n";
    $out .= " - limit________: "
      . ( $Channel->ulimit ? $Channel->ulimit : "" ) . "\n";
    $out .=
      " - auto topic___: " . ( $Channel->auto_topic ? "yes" : "no" ) . "\n";
    $out .=
      " - topic________: " . ( $Channel->topic ? $Channel->topic : "" ) . "\n";
    $out .= " - auto op______: " . ( $Channel->auto_op ? "yes" : "no" ) . "\n";
    $out .=
      " - auto voice___: " . ( $Channel->auto_voice ? "yes" : "no" ) . "\n";
    $out .= " - active_______: " . ( $Channel->active ? "yes" : "no" ) . "\n";
    $out .=
      " - bot joined___: " . ( $Channel->bot_joined ? "yes" : "no" ) . "\n";

    my @lines = split( /\n/, $out );
    $self->_send_lines( $irc, 'notice', $Session->nick, @lines );
    return PCI_EAT_ALL;
}

sub channel_set {
    my ( $self, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'channel_set';
    my $PCMD    = $self->get_cmd($cmdname);
    my $db      = $irc->{database};
    unless ( $Session->user_id ) {
        $irc->yield(
            notice => $Session->nick => "[$cmdname] You must be logged!" );
        return PCI_EAT_ALL;
    }
    if ( $User->lvl < $PCMD->{lvl} ) {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] You don't have the right to set channel information!"
        );
        return PCI_EAT_ALL;
    }
    my ( $cmd, $chan, $key, $value ) = split /\s+/, $msg;
    $chan =~ /^([#&])([^\s]+)$/ or do {
        $irc->yield(
            notice => $Session->nick => "[$cmdname] Invalid channel name!" );
        return PCI_EAT_ALL;
    };
    my ( $type, $name ) = ( $1, $2 );
    unless ( is_valid_chan_name("$type$name") ) {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] Invalid channel name '$type$name'!" );
        return PCI_EAT_ALL;
    }
    my $Channel = $db->Channels->get_by( $type, $name );
    unless ($Channel) {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] Channel '$type$name' not found!" );
        return PCI_EAT_ALL;
    }
    my @akeys =
      qw(ulimit auto_mode auto_topic auto_op auto_voice active topic password  mode);
    unless ( grep /^$key$/, @akeys ) {
        $irc->yield(
            notice => $Session->nick => "[$cmdname] Invalid key $key" );
        return PCI_EAT_ALL;
    }

    if ( $key eq 'ulimit' ) {
        $value = abs( int($value) );
    }
    elsif ( $key eq 'password' ) {
        $value =~ s/[^\w\d_-]//g if $value;
    }
    elsif ( $key =~ /^(auto_(mode|topic|op|voice)|active)$/ ) {
        $value = int($value);
        $value = 1 if $value;
    }
    elsif ( $key eq "mode" ) {
        $value =~ s/[^pstnmi]//g;
    }
    my $mode_change = 0;
    if ( $key =~ /^(ulimit|password|mode|auto_mode)$/ ) {
        $mode_change = 1
          if ( ( defined $Channel->$key and not defined $value )
            or ( not defined $Channel->$key and defined $value )
            or ( $Channel->$key != $value )
            or ( $Channel->$key ne $value ) );
    }
    $Channel->$key($value);
    if ( $Channel->_update ) {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] Successfuly set $key to $value" );
        $irc->yield( 'mode', $Channel->_usable_name )
          if $mode_change and $Channel->auto_mode;
    }
    else {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] Cannot set $key to $value" );
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
    for my $Chan (@list) {
        my ( $owner, $Owner );
        if ( $Chan->owner ) {
            $Owner = $db->Users->get( $Chan->owner );
            $owner = $Owner->name;
        }
        else {
            $owner = "No Owner";
        }
        my $str = " - ";
        $str .= localtime( int $Chan->created_on );
        $str .= " - [ " . str_fixsize( "$owner ]", 15 );
        $str .= $Chan->_usable_name;

        $irc->yield( notice => $Session->nick => $str );
    }
    return PCI_EAT_ALL;
}

sub channel_set_owner {
    my ( $self, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'channel_set_owner';
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
            notice => $Session->nick => "[$cmdname] Invalid user name, "
              . $self->pretty_help($cmdname) );
        return PCI_EAT_ALL;
    };
    my $Channel = $db->Channels->get_by( $type, $channame );
    unless ($Channel) {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] No channel named '$type$channame'" );
        return PCI_EAT_ALL;
    }
    my $Owner = $db->Users->get_by( { name => $name } );
    unless ($Owner) {
        $irc->yield(
            notice => $Session->nick => "[$cmdname] No user named '$name'" );
        return PCI_EAT_ALL;
    }
    my $CurrentOwner;
    if ( $Channel->owner ) {
        $CurrentOwner = $db->Users->get( $Channel->owner );
        if ( ( $User->lvl != 1000 ) and ( $CurrentOwner->lvl >= $User->lvl ) ) {
            $irc->yield( notice => $Session->nick =>
                  "[$cmdname] You cannot change this channel owner!" );
            return PCI_EAT_ALL;
        }
        elsif ( $CurrentOwner->id == $Owner->id ) {
            $irc->yield( notice => $Session->nick => "[$cmdname] Same owner!" )
              ;
            return PCI_EAT_ALL;
        }
    }

    $Channel->owner( $Owner->id );

    if ( $Channel->_update ) {
        $irc->yield( notice => $Session->nick => "[$cmdname] "
              . $Channel->_usable_name
              . " owner set to "
              . $Owner->name );
        return PCI_EAT_ALL;
    }
    else {
        $irc->yield( notice => $Session->nick => "[$cmdname] Cannot set "
              . $Channel->_usable_name
              . " owner set to "
              . $Owner->name );
        return PCI_EAT_ALL;
    }

}

sub join {
    my ( $self, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'op';
    my $PCMD    = $self->get_cmd($cmdname);
    my $db      = $irc->{database};

    unless ( $Session->user_id ) {
        $irc->yield(
            notice => $Session->nick => "[$cmdname] You must be logged!" );
        return PCI_EAT_ALL;
    }
    if ( $User->lvl < $PCMD->{lvl} ) {
        $irc->yield( notice => $Session->nick => "[$cmdname] You !" );
        return PCI_EAT_ALL;
    }
    my @channels = split /\s+/, $msg;
    shift @channels;    # First argument is the command
    if ( $event eq "S_public" ) {
        push @channels, $where->[0];
    }
    for (@channels) {
        $irc->{Shoze}->POE->IRC->Out->join( $User, $_ );
    }
    return PCI_EAT_ALL;
}

sub part {
    my ( $self, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'op';
    my $PCMD    = $self->get_cmd($cmdname);
    my $db      = $irc->{database};

    unless ( $Session->user_id ) {
        $irc->yield(
            notice => $Session->nick => "[$cmdname] You must be logged!" );
        return PCI_EAT_ALL;
    }
    if ( $User->lvl < $PCMD->{lvl} ) {
        $irc->yield( notice => $Session->nick => "[$cmdname] You !" );
        return PCI_EAT_ALL;
    }
    my @channels = split /\s+/, $msg;
    shift @channels;    # First argument is the command
    if ( $event eq "S_public" ) {
        push @channels, $where->[0];
    }
    for (@channels) {
        $irc->{Shoze}->POE->IRC->Out->part( $User, $_ );
    }
    return PCI_EAT_ALL;
}

sub topic {
    my ( $self, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'topic';
    my $PCMD    = $self->get_cmd($cmdname);
    my $db      = $irc->{database};

    unless ( $Session->user_id ) {
        $irc->yield(
            notice => $Session->nick => "[$cmdname] You must be logged!" );
        return PCI_EAT_NONE;
    }
    if ( $User->lvl < $PCMD->{lvl} ) {
        $irc->yield( notice => $Session->nick => "[$cmdname] You !" );
        return PCI_EAT_NONE;
    }
    my $channel;
    my $topic;
    if ( $event eq "S_msg" ) {
        $msg =~ s/^!topic\s+([#&][\w\d_-]+)\s+(.*)\s*$/$2/ and do {
            $channel = $1;
            $topic   = $2;
        };
    }
    else {
        $msg =~ s/^!topic\s+(.*)\s*$/$1/ and do {
            $channel = $where->[0];
            $topic   = $1;
        };
    }
    LOG("[$event] Want to set topic on '$channel': $msg");
    return PCI_EAT_NONE unless is_valid_chan_name($channel);
    my $Channel = $db->Channels->get_by($channel);
    LOG("Want to set topic: chan ok");
    return PCI_EAT_NONE unless $Channel;
    my $can = 0;
    if ( $User->lvl >= 800 ) {
        $can = 1;
    }
    elsif ( $User->id == $Channel->owner ) {
        $can = 1;
    }
    else {
        return PCI_EAT_NONE;
    }
    $Channel->topic($topic);
    $Channel->topic_setby( $User->id );
    $Channel->topic_seton(time);
    unless ( $Channel->_update ) {
        WARN("Cannot update channel $channel with new topic informations");
        return PCI_EAT_NONE;
    }
    if ($topic) {
        $topic .=
          " (" . $User->name . "/" . localtime( $Channel->topic_seton ) . ")";
    }
    $irc->yield( 'topic' => $channel => $topic );
    return PCI_EAT_ALL;
}

sub op {
    my ( $self, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'op';
    my $PCMD    = $self->get_cmd($cmdname);
    my $db      = $irc->{database};

    unless ( $Session->user_id ) {
        $irc->yield(
            notice => $Session->nick => "[$cmdname] You must be logged!" );
        return PCI_EAT_ALL;
    }
    if ( $User->lvl < $PCMD->{lvl} ) {
        $irc->yield( notice => $Session->nick => "[$cmdname] You !" );
        return PCI_EAT_ALL;
    }
    my @channels = split /\s+/, $msg;
    shift @channels;    # First argument is the command
    if ( $event eq "S_public" ) {
        push @channels, $where->[0];
    }
    for (@channels) {
        next unless is_valid_chan_name($_);
        /^(#|&)(.*)$/;
        my ( $type, $channame ) = ( $1, $2 );
        my $Channel = $db->Channels->get_by( $type, $channame );
        next unless $Channel;
        my $canop = 0;
        if ( $User->lvl >= 800 ) {
            $canop = 1;
        }
        elsif ( $Channel->owner and ( $User->id == $Channel->owner ) ) {
            $canop = 1;
        }
        else {
            LOG("Checking user channel right");
        }
        if ($canop) {
            $irc->yield( 'mode', "$_ +o " . $Session->nick );
        }
    }
}

sub deop {
    my ( $self, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'op';
    my $PCMD    = $self->get_cmd($cmdname);
    my $db      = $irc->{database};

    unless ( $Session->user_id ) {
        $irc->yield(
            notice => $Session->nick => "[$cmdname] You must be logged!" );
        return PCI_EAT_ALL;
    }
    if ( $User->lvl < $PCMD->{lvl} ) {
        $irc->yield( notice => $Session->nick => "[$cmdname] You !" );
        return PCI_EAT_ALL;
    }
    my $channel = $where->[0];
    if ( $User->lvl >= 800 ) {
        LOG( $User->name . "800+ request deop on $channel" );
        $self->deop_who_on( $irc, $Session->nick, $channel );
        return PCI_EAT_ALL;
    }
    $irc->yield(
        notice => $Session->nick => "[$cmdname] DeOp not implemented :)" );
    return PCI_EAT_ALL;
}

sub deop_who_on {
    my $s = shift;
    my ( $irc, $nick, $channel ) = @_;
    $irc->yield( 'mode', "$channel -o $nick" );
}

sub op_who_on {
    my $s = shift;
    my ( $irc, $nick, $channel ) = @_;
    $irc->yield( 'mode', "$channel +o $nick" );
}

1;
