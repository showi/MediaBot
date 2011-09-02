package MediaBot::IRC::BotCmdPlus::Plugins::Channel;

use strict;
use warnings;

use Carp;

use POE::Component::IRC::Plugin qw(:ALL);
use IRC::Utils qw(:ALL);

use lib qw(../../../../);
use MediaBot::Class qw(AUTOLOAD DESTROY);
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
            'channel_set_owner' => {
                access   => 'msg',
                lvl      => 800,
                help_cmd => '!channel.set.owner [#|&]channel_name name',
                help_description =>
'Listing channel. you must be admin or owner of the bot (>800)',
            },
            'op' => {
                access           => 'public|msg',
                lvl              => 200,
                help_cmd         => '!op <channel list>',
                help_description => 'Give you op!',
            },
            'deop' => {
                access           => 'public|msg',
                lvl              => 200,
                help_cmd         => '!deop <channel list>',
                help_description => 'Deop you!',
            },
            'join' => {
                access           => 'public|msg',
                lvl              => 200,
                help_cmd         => '!join <channel list>',
                help_description => 'Make bot joining channel!',
            },
            'part' => {
                access           => 'public|msg',
                lvl              => 200,
                help_cmd         => '!part <channel list>',
                help_description => '!Make bot leavin channel',
            },
            'topic' => {
                access           => 'public|msg',
                lvl              => 500,
                help_cmd         => '!topic <channel> [topic]',
                help_description => '!set channel topic',
            }
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
    shift @channels; # First argument is the command
    if ($event eq "S_public") {
        push @channels, $where->[0];
    } 
    for(@channels) {
         next unless is_valid_chan_name($_);
         /^(#|&)(.*)$/;
         my ($type, $channame) = ($1, $2);
         my $Channel = $db->Channels->get_by($type, $channame);
         next unless $Channel;
         my $can = 0;
         if ($User->lvl >= 800) {
             $can = 1;
         } elsif($Channel->owner and ($User->id == $Channel->owner)) {
             $can = 1;
         } 
         if ($can) {
             $irc->yield( 'join', $_);
         }    
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
    shift @channels; # First argument is the command
    if ($event eq "S_public") {
        push @channels, $where->[0];
    } 
    for(@channels) {
         next unless is_valid_chan_name($_);
         /^(#|&)(.*)$/;
         my ($type, $channame) = ($1, $2);
         my $Channel = $db->Channels->get($type, $channame);
         next unless $Channel;
         my $can = 0;
         if ($User->lvl >= 800) {
             LOG("Leaving $_");
             $can = 1;
         } elsif($Channel->owner and ($User->id == $Channel->owner)) {
             $can = 1;
         } 
         if ($can) {
             $irc->yield( 'part', $_);
         }    
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
    if ($event eq "S_msg") {
        $msg =~ s/^!topic\s+([#&][\w\d_-]+)\s+(.*)\s*$/$2/;
        $channel = $1;
    } else {
        $msg =~ s/^!topic\s+(.*)\s*$/$1/;
        $channel = $where->[0];
    }
    LOG("[$event] Want to set topic on '$channel': $msg");
    return PCI_EAT_NONE unless is_valid_chan_name($channel);
      LOG("Want to set topic: chan ok");
    my $Channel = $db->Channels->get_by_name($channel);
    
    return PCI_EAT_NONE unless $Channel;
  
    my $can = 0;
    if ($User->lvl >= 800) {
        $can = 1;
    } elsif ($User->id == $Channel->owner) {
        $can = 1;
    } else {
        return PCI_EAT_NONE;
    }
    $irc->yield('topic' => $channel => $msg);
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
    shift @channels; # First argument is the command
    if ($event eq "S_public") {
        push @channels, $where->[0];
    } 
    for(@channels) {
         next unless is_valid_chan_name($_);
         /^(#|&)(.*)$/;
         my ($type, $channame) = ($1, $2);
         my $Channel = $db->Channels->get_by($type, $channame);
         next unless $Channel;
         my $canop = 0;
         if ($User->lvl >= 800) {
             $canop = 1;
         } elsif($Channel->owner and ($User->id == $Channel->owner)) {
             $canop = 1;
         } else {
             LOG("Checking user channel right");
         }
         if ($canop) {
             $irc->yield( 'mode', "$_ +o ". $Session->nick );
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
