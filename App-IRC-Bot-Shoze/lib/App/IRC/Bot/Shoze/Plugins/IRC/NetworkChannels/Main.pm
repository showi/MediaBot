package App::IRC::Bot::Shoze::Plugins::IRC::NetworkChannels::Main;

=head1 NAME

App::IRC::Bot::Shoze::Plugins::IRC::NetworkChannels::Main - NetworkChannels plugin

=cut

=head1 SYNOPSIS

This plugin allow administrator to manage channels and user

=cut

use strict;
use warnings;

use Carp;

use POE::Component::IRC::Plugin qw(:ALL);
use IRC::Utils qw(:ALL);

use lib qw(../../../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::String;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Helper qw(:ALL);

our %fields = ( cmd => undef );

=head1 SUBROUTINES/METHODS

=over

=item new

=cut

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
            'voice' => {
                access           => 'public|msg',
                lvl              => 200,
                help_cmd         => '!op [channel list]',
                help_description => 'Give you op!',
            },
            'devoice' => {
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

=item channel_del

=cut

sub channel_del {
    my ( $s, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'channel_add';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = App::IRC::Bot::Shoze::Db->new;

    my ($channame) = ( split( /\s+/, $msg ) )[1];
    $channame =~ /^(#|&)([\w\d_]+)$/ or do {
        return $s->_n_error( $irc, $Session,
            "[$cmdname] Invalid syntax, " );
    };
    my $type;
    ( $type, $channame ) = ( $1, $2 );
    my $Channel =
      $db->NetworkChannels->get_by( $irc->{Network},
        { type => $type, name => $channame } );
    if ( !$Channel ) {
        return $s->_n_error( $irc, $Session,
            "[$cmdname] Channel doesn't exist!" );
    }

    LOG("Deleting channel '$channame'");
    $irc->{Out}->part($Session->get_hostmask, $Channel->_usable_name, $Channel);
    if ( $db->NetworkChannels->delete($Channel) ) {
        $irc->{Out}->notice('#me#', $Session,
              "[$cmdname] Channel $type$channame deleted." );
        my $aj = $irc->plugin_get('AutoJoin');
        delete $aj->{Channels}->{"$type$channame"};
       
    }
    else {
        $irc->{Out}->join($Session->get_hostmask, $Channel->_usable_name, $Channel );
        return $s->_n_error( $irc, $Session,
            "[$cmdname] Cannot delete channel $type$channame" );
    }
    return PCI_EAT_ALL;
}

=item channel_add

=cut

sub channel_add {
    my ( $s, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'channel_add';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = App::IRC::Bot::Shoze::Db->new;

    my ($channame) = ( split( /\s+/, $msg ) )[1];

    my ( $ctype, $cname ) = splitchannel($channame);
    my $Channel =
      $db->NetworkChannels->get_by( $irc->{Network},
        { type => $ctype, name => $cname } );
    if ($Channel) {
        return $s->_n_error( $irc, $Session,
                "[$cmdname] Channel '"
              . $Channel->_usable_name
              . "' already exist!" );
    }
    LOG("Creating channel '$channame'");
    $Channel =
      $db->NetworkChannels->create( $irc->{Network}, $ctype, $cname,
        $Session->user_id );
    if ($Channel) {
        $irc->{Out}->notice('#me#', $Session->nick,,
              "[$cmdname] Channel $ctype$cname created." );
        my $aj = $irc->plugin_get('AutoJoin');
        $aj->{Channels}->{"$ctype$cname"} = '';
        $Channel = $db->NetworkChannels->get_by($irc->{Network}, {type => $ctype, name => $cname});
        $irc->{Out}->join($Session->get_hostmask, $Channel->_usable_name, $Channel);
    }
    else {
        return $s->_n_error( $irc, $Session,
            "[$cmdname] Cannot create channel $ctype$cname" );
    }
    return PCI_EAT_ALL;
}

=item channel_info

=cut

sub channel_info {
    my ( $s, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'channel_info';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = App::IRC::Bot::Shoze::Db->new;

    print "msg: $msg\n";
    my $chan = ( split( /\s+/, $msg ) )[1];
    $chan =~ /^([#&])([^\s]+)/ or do {
        return $s->_n_error( $irc, $Session,
            "[$cmdname] Invalid channel name!" );
    };
    my ( $type, $name ) = ( $1, $2 );
    unless ( is_valid_chan_name("$type$name") ) {
        return $s->_n_error( $irc, $Session,
            "[$cmdname] Invalid channel name $type$name" );
    }
    my $Channel =
      $db->NetworkChannels->get_by( $irc->{Network},
        { type => $type, name => $name } );
    unless ($Channel) {
        return $s->_n_error( $irc, $Session,
            "[$cmdname] Channel $type$name not found!" );
    }
    my $Owner;
    if ( $Channel->owner ) {
        $Owner = $db->Users->get( $Channel->owner );
    }
    my $out = "Channel information [$type$name] ("
      . localtime( int $Channel->created_on ) . ")";
    $out .= ( $Owner ? " (" . $Owner->name . ")\n" : "\n" );
    $out .= " - bot mode_____: "
      . ( $Channel->bot_mode ? "+" . $Channel->bot_mode : "" ) . "\n";
    $out .=
      " - auto mode____: " . ( $Channel->auto_mode ? "yes" : "no" ) . "\n";
    $out .= " - mode_________: "
      . ( $Channel->wanted_mode ? "+" . $Channel->wanted_mode : "" ) . "\n";
    $out .= " - password_____: "
      . ( $Channel->wanted_password ? $Channel->wanted_password : "" ) . "\n";
    $out .= " - limit________: "
      . ( $Channel->wanted_ulimit ? $Channel->wanted_ulimit : "" ) . "\n";
    $out .=
      " - auto topic___: " . ( $Channel->auto_topic ? "yes" : "no" ) . "\n";
    $out .=
      " - topic________: " . ( $Channel->wanted_topic ? $Channel->wanted_topic : "" ) . "\n";
    $out .= " - auto op______: " . ( $Channel->auto_op ? "yes" : "no" ) . "\n";
    $out .=
      " - auto voice___: " . ( $Channel->auto_voice ? "yes" : "no" ) . "\n";
    $out .= " - active_______: " . ( $Channel->active ? "yes" : "no" ) . "\n";
    $out .=
      " - bot joined___: " . ( $Channel->bot_joined ? "yes" : "no" ) . "\n";
    $out .= " - updated on___: " . localtime( int $Channel->updated_on ) . "\n";
    my @lines = split( /\n/, $out );
    $s->_send_lines( $irc, 'notice', '#me#', $Session, @lines );
    return PCI_EAT_ALL;
}

=item channel_set

=cut

sub channel_set {
    my ( $s, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'channel_set';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = App::IRC::Bot::Shoze::Db->new;

    my ( $cmd, $chan, $key, $value ) = split /\s+/, $msg;
    $chan =~ /^([#&])([^\s]+)$/ or do {
        return $s->_n_error( $irc, $Session,
            "[$cmdname] Invalid channel name!" );
    };
    my ( $type, $name ) = ( $1, $2 );
    unless ( is_valid_chan_name("$type$name") ) {
        return $s->_n_error( $irc, $Session,
            "[$cmdname] Invalid channel name '$type$name'!" );
    }
    my $Channel =
      $db->NetworkChannels->get_by( $irc->{Network},
        { type => $type, name => $name } );
    unless ($Channel) {
        return $s->_n_error( $irc, $Session,
            "[$cmdname] Channel '$type$name' not found!" );
    }
    my @akeys =
      qw(auto_mode auto_topic auto_op auto_voice active wanted_topic wanted_password wanted_mode wanted_ulimit );
    unless ( grep /^$key$/, @akeys ) {
        return $s->_n_error( $irc, $Session,
            "[$cmdname] Invalid key $key" );
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
        $irc->notice('#me#', $Session, 
              "[$cmdname] Successfuly set $key to $value" );
        $irc->yield( 'mode', $Channel->_usable_name )
          if $mode_change and $Channel->auto_mode;
    }
    else {
        return $s->_n_error( $irc, $Session,
            "[$cmdname] Cannot set $key to $value" );
    }
    return PCI_EAT_ALL;
}

=item channel_list

=cut

sub channel_list {
    my ( $s, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'channel_list';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = App::IRC::Bot::Shoze::Db->new;

    my @list = $db->NetworkChannels->list( $irc->{Network} );
    unless (@list) {
        return $s->_n_error( $irc, $Session->nick,
            "[$cmdname] No channel in database " );
        return PCI_EAT_ALL;
    }
    $irc->{Out}->notice('#me#', $Session, "[$cmdname] Listing channel " );
    for my $Chan (@list) {
        my ( $owner, $Owner );
        if ( $Chan->owner ) {
            $Owner = $db->Users->get( $Chan->owner );
            $owner = $Owner->name;
        }
        else {
            $owner = "No Owner";
        }
        my $str = ' - ';
        $str .= localtime( int $Chan->created_on );
        $str .= ' - [ ' . str_fixsize( "$owner ]", 10 );
        $str .= $Chan->_usable_name;
        $str .= ' (' . localtime( int $Chan->updated_on ) . ')'
          if $Chan->updated_on;
        $irc->{Out}->notice('#me#', $Session, $str );
    }
    return PCI_EAT_ALL;
}

=item channel_set_owner

=cut

sub channel_set_owner {
    my ( $s, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'channel_set_owner';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = App::IRC::Bot::Shoze::Db->new;

    LOG("msg: $msg");
    my ( $channame, $name ) = ( split( /\s+/, $msg ) )[ 1 .. 2 ];
    $channame =~ /^(#|&)([\w\d_-]+)$/ or do {
        return $s->_n_error( $irc, $Session,
            "[$cmdname] Invalid channel name, " . $s->pretty_help($cmdname) );
    };
    my $type;
    ( $type, $channame ) = ( $1, $2 );
    $name =~ /^[\w\d_-]+$/ or do {
        return $s->_n_error( $irc, $Session,
            "[$cmdname] Invalid user name, " . $s->pretty_help($cmdname) );
    };
    my $Channel =
      $db->NetworkChannels->get_by( $irc->{Network},
        { type => $type, name => $channame } );
    unless ($Channel) {
        return $s->_n_error( $irc, $Session,
            "[$cmdname] No channel named '$type$channame'" );
    }
    my $Owner = $db->Users->get_by( { name => $name } );
    unless ($Owner) {
        return $s->_n_error( $irc, $Session,
            "[$cmdname] No user named '$name'" );
        return PCI_EAT_ALL;
    }
    my $CurrentOwner;
    if ( $Channel->owner ) {
        $CurrentOwner = $db->Users->get( $Channel->owner );
        if (    ( $Session->user_lvl != 1000 )
            and ( $CurrentOwner->lvl >= $Session->user_lvl ) )
        {
            $irc->{Out}->notice('#me#', $Session,
                  "[$cmdname] You cannot change this channel owner!" );
            return PCI_EAT_ALL;
        }
        elsif ( $CurrentOwner->id == $Owner->id ) {
            $irc->{Out}->notice('#me#', $Session->nick => "[$cmdname] Same owner!" );
            return PCI_EAT_ALL;
        }
    }

    $Channel->owner( $Owner->id );

    if ( $Channel->_update ) {
        $irc->{Out}->notice('#me#', $Session, "[$cmdname] "
              . $Channel->_usable_name
              . " owner set to "
              . $Owner->name );
        return PCI_EAT_ALL;
    }
    else {
        $irc->{Out}->notice('#me#', $Session->nick => "[$cmdname] Cannot set "
              . $Channel->_usable_name
              . " owner set to "
              . $Owner->name );
        return PCI_EAT_ALL;
    }

}

=item join

=cut

sub join {
    my ( $s, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'join';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = App::IRC::Bot::Shoze::Db->new;

    my @channels = split /\s+/, $msg;
    shift @channels;    # First argument is the command
    if ( $event eq "S_public" ) {
        push @channels, $where->[0];
    }
    for (@channels) {
        my ( $ctype, $cname ) = splitchannel($_);
        #print "Cname: $cname, Ctype: $ctype, NetworkID: " . $irc->{Network}->id . "\n";
        my $Channel = $db->NetworkChannels->get_by(
            $irc->{Network},
            {
                name => $cname,
                type => $ctype
            }
        );
        #print "Channel: " . $Channel . "\n";
        unless ($Channel) {
            WARN("Cannot join unmanaged channel '$_'");
            next;
        }
        $s->_join( $irc, $Channel );
    }
    return PCI_EAT_ALL;
}

=item part

=cut

sub part {
    my ( $self, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'op';
    my $PCMD    = $self->get_cmd($cmdname);
    my $db      = App::IRC::Bot::Shoze::Db->new;

    my @channels = split /\s+/, $msg;
    shift @channels;    # First argument is the command
    if ( $event eq "S_public" ) {
        push @channels, $where->[0];
    }
    for (@channels) {
        $irc->yield( part => $_ );
    }
    return PCI_EAT_ALL;
}

=item topic

=cut

sub topic {
    my ( $self, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'topic';
    my $PCMD    = $self->get_cmd($cmdname);
    my $db      = App::IRC::Bot::Shoze::Db->new;

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
    my ( $type, $channame ) = ( $channel =~ /^(#|&)(.*)$/ );
    my $Channel =
      $db->NetworkChannels->get_by( $irc->{Network},
        { type => $type, name => $channame } );
    LOG("Want to set topic: chan ok");
    return PCI_EAT_NONE unless $Channel;
    my $can = 0;

    if ( $Session->user_lvl >= 800 ) {
        $can = 1;
    }
    elsif ( $Session->user_id == $Channel->owner ) {
        $can = 1;
    }
    else {
        return PCI_EAT_NONE;
    }
    $Channel->wanted_topic($topic);
    $Channel->topic_setby( $Session->user_id );
    $Channel->topic_seton(time);
    unless ( $Channel->_update ) {
        WARN("Cannot update channel $channel with new topic informations");
        return PCI_EAT_NONE;
    }
    if ($topic) {
        $topic .= " ("
          . $Session->user_name . "/"
          . localtime( $Channel->topic_seton ) . ")";
    }
    $irc->yield( 'topic' => $channel => $topic );
    return PCI_EAT_ALL;
}

=item op

=cut

sub op {
    my ( $s, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'op';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = App::IRC::Bot::Shoze::Db->new;

    my ( $cmd, $channel, @nicks );
    if ( $event eq 'S_public' ) {
        $channel = $where->[0];
        ( $cmd, @nicks ) = split /\s+/, $msg;
    }
    else {
        ( $cmd, $channel, @nicks ) = split /\s+/, $msg;
    }
    unless (@nicks) {
        push @nicks, $Session->nick;
    }
    my ( $ctype, $cname ) = splitchannel($channel);
    my $Channel =
      $db->NetworkChannels->get_by( $irc->{Network},
        { type => $ctype, name => $cname } );
    unless ($Channel) {
        WARN("Channel '$channel' is not managed");
        return PCI_EAT_NONE;
    }
    unless ( $s->can_op( $irc, $Session, $Channel ) ) {
        WARN(   'User '
              . $Session->nick
              . ' don\'t have the right to op people on channel \''
              . $channel
              . '\'' );
        return PCI_EAT_NONE;
    }

    $s->_modes( $irc, '+', 'o', $Channel, @nicks );
}

=item deop

=cut

sub deop {
    my ( $s, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'deop';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = App::IRC::Bot::Shoze::Db->new;

    my ( $cmd, $channel, @nicks );
    if ( $event eq 'S_public' ) {
        $channel = $where->[0];
        ( $cmd, @nicks ) = split /\s+/, $msg;
    }
    else {
        ( $cmd, $channel, @nicks ) = split /\s+/, $msg;
    }
    unless (@nicks) {
        push @nicks, $Session->nick;
    }
    my ( $ctype, $cname ) = splitchannel($channel);
    my $Channel =
      $db->NetworkChannels->get_by( $irc->{Network},
        { type => $ctype, name => $cname } );
    unless ($Channel) {
        WARN("Channel '$channel' is not managed");
        return PCI_EAT_NONE;
    }
    unless ( $s->can_op( $irc, $Session, $Channel ) ) {
        WARN(   'User '
              . $Session->nick
              . ' don\'t have the right to op people on channel \''
              . $channel
              . '\'' );
        return PCI_EAT_NONE;
    }

    $s->_modes( $irc, '-', 'o', $Channel, @nicks );
    return PCI_EAT_ALL;
}

=item voice

=cut

sub voice {
    my ( $s, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'op';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = App::IRC::Bot::Shoze::Db->new;

    my ( $cmd, $channel, @nicks );
    if ( $event eq 'S_public' ) {
        $channel = $where->[0];
        ( $cmd, @nicks ) = split /\s+/, $msg;
    }
    else {
        ( $cmd, $channel, @nicks ) = split /\s+/, $msg;
    }
    unless (@nicks) {
        push @nicks, $Session->nick;
    }
    my ( $ctype, $cname ) = splitchannel($channel);
    my $Channel =
      $db->NetworkChannels->get_by( $irc->{Network},
        { type => $ctype, name => $cname } );
    unless ($Channel) {
        WARN("Channel '$channel' is not managed");
        return PCI_EAT_NONE;
    }
    unless ( $s->can_voice( $irc, $Session, $Channel ) ) {
        WARN(   'User '
              . $Session->nick
              . ' don\'t have the right to voice people on channel \''
              . $channel
              . '\'' );
        return PCI_EAT_NONE;
    }
    $s->_modes( $irc, '+', 'v', $Channel, @nicks );
    return PCI_EAT_ALL;
}

=item devoice

=cut

sub devoice {
    my ( $s, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'op';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = App::IRC::Bot::Shoze::Db->new;

    my ( $cmd, $channel, @nicks );
    if ( $event eq 'S_public' ) {
        $channel = $where->[0];
        ( $cmd, @nicks ) = split /\s+/, $msg;
    }
    else {
        ( $cmd, $channel, @nicks ) = split /\s+/, $msg;
    }
    unless (@nicks) {
        push @nicks, $Session->nick;
    }
    my ( $ctype, $cname ) = splitchannel($channel);
    my $Channel =
      $db->NetworkChannels->get_by( $irc->{Network},
        { type => $ctype, name => $cname } );
    unless ($Channel) {
        WARN("Channel '$channel' is not managed");
        return PCI_EAT_NONE;
    }
    unless ( $s->can_voice( $irc, $Session, $Channel ) ) {
        WARN(   'User '
              . $Session->nick
              . ' don\'t have the right to voice people on channel \''
              . $channel
              . '\'' );
        return PCI_EAT_NONE;
    }
    $s->_modes( $irc, '-', 'v', $Channel, @nicks );
    return PCI_EAT_ALL;
}

=item deop_who_on

=cut

sub deop_who_on {
    my $s = shift;
    my ( $irc, $nick, $channel ) = @_;
    $irc->yield( 'mode', "$channel -o $nick" );
}

=item op_who_on

=cut

sub op_who_on {
    my $s = shift;
    my ( $irc, $nick, $channel ) = @_;
    $irc->yield( 'mode', "$channel +o $nick" );
}

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2011 Joachim Basmaison.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;
