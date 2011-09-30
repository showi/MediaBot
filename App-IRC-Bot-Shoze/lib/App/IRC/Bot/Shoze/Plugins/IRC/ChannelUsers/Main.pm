package App::IRC::Bot::Shoze::Plugins::IRC::ChannelUsers::Main;

=head1 NAME

App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::ChannelUsers - ChannelUsers plugin

=cut

=head1 SYNOPSIS
    
The plugin allow admin and channel owner to link user to channel and
manage their rights.
TODO: Find another name so we want confuse this plugin with
NetworkChannelUsers who store current people who have joined this channel

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
use App::IRC::Bot::Shoze::Db::ChannelUsers::Object;

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
           'channel_user_add' => {
               access   => 'msg',
               lvl      => 500,
               help_cmd => '!channel.user.add <channel name> <user name> [lvl]',
               help_description => 'Link user to a given channel',
           },
           'channel_user_list' => {
                             access   => 'msg',
                             lvl      => 500,
                             help_cmd => '!channel.user.list <channel name>',
                             help_description =>
                               'Listing user\'s linked to a particular channel',
           },
           'channel_user_del' => {
                          access   => 'msg',
                          lvl      => 500,
                          help_cmd => '!channel.user.del <channel name> <user>',
                          help_description =>
                            'Remove a linked user from a specified channel',
           },
           'channel_user_set' => {
               access => 'msg',
               lvl    => 500,
               help_cmd =>
'!channel.user.set <channel name> <user> <lvl|auto_mode> <value>',
               help_description =>
                 'Remove a linked user from a specified channel',
           },
           'channel_user_info' => {
                          access   => 'msg',
                          lvl      => 500,
                          help_cmd => '!channel.user.set <channel name> <user>',
                          help_description => 'Get channel user information',
           },
        }
    );
    return $s;
}

=item channel_user_add

=cut

sub channel_user_add {
    my ( $s, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'channel_user_add';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = App::IRC::Bot::Shoze::Db->new;
    $msg = str_chomp($msg);
    my ( $cmd, $chan, $uname, $lvl ) = split /\s+/, $msg;
    LOG("$cmdname: $chan $uname $lvl");

    unless ( is_valid_chan_name($chan) ) {
        return $s->_n_error( $irc, $Session, "Invalid channel name '$chan'" );
    }
    my ( $type, $channame ) = splitchannel($chan);
    my $Channel = $db->NetworkChannels->get_by( $irc->{Network},
                                         { type => $type, name => $channame } );
    unless ($Channel) {
        return $s->_n_error( $irc, $Session, "Channel '$chan' not found" );
    }
    if (     ( $Channel->owner != $Session->user_id )
         and ( $Session->user_lvl < 800 ) )
    {
        return
          $s->_n_error( $irc, $Session,
                        "You can't add user to channel '$chan'" );
    }
    unless ( $uname =~ /^[\w\d_-]+/ ) {
        return $s->_n_error( $irc, $Session, "Invalid user name '$uname'" );
    }
    my $TUser = $db->Users->get_by( { name => $uname } );
    unless ($TUser) {
        return $s->_n_error( $irc, $Session, "User $uname not found" );
    }
    my $ChannelUser = $db->ChannelUsers->get_by(
                        { channel_id => $Channel->id, user_id => $TUser->id } );
    if ($ChannelUser) {
        return
          $s->_n_error( $irc, $Session,
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
    unless ( $ChannelUser->_create ) {
        return
          $s->_n_error( $irc, $Session,
                        "Cannot link user '$uname' to channel '$chan'" );
    } else {
        $irc->{Out}->notice( '#me#', $Session,
                 "User '$uname' linked to channel '$chan' with level $setlvl" );
    }
    return PCI_EAT_ALL;
}

=item channel_user_set

=cut

sub channel_user_set {
    my ( $s, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'channel_user_set';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = App::IRC::Bot::Shoze::Db->new;

    $msg = str_chomp($msg);
    my ( $cmd, $chan, $uname, $key, $value ) = split /\s+/, $msg;
    LOG("$cmdname: $chan $uname $key $value");
    my @authkeys = qw(lvl auto_mode);

    unless ( grep $key, @authkeys ) {
        return $s->_n_error( $irc, $Session, "Invalid keys '$key'" );
    }
    unless ( is_valid_chan_name($chan) ) {
        return $s->_n_error( $irc, $Session, "Invalid channel name '$chan'" );
    }
    my ( $type, $channame ) = ( $chan =~ /^(#|&)(.*)$/ );
    my $Channel = $db->NetworkChannels->get_by( $irc->{Network},
                                         { type => $type, name => $channame } );
    unless ($Channel) {
        return $s->_n_error( $irc, $Session, "Channel '$chan' not found" );
    }
    if (     ( $Channel->owner != $Session->user_id )
         and ( $Session->user_lvl < 800 ) )
    {
        return
          $s->_n_error( $irc, $Session,
                        "You can't set key '$key' to channel '$chan'" );
    }
    my $TUser = $db->Users->get_by( { name => $uname } );
    unless ($TUser) {
        return $s->_n_error( $irc, $Session, "Unknow user '$uname'" );
    }
    my $MeChanUser = $db->ChannelUsers->get_by(
                 { channel_id => $Channel->id, user_id => $Session->user_id } );
    my $TChanUser = $db->ChannelUsers->get_by(
                        { channel_id => $Channel->id, user_id => $TUser->id } );
    if ( $key eq "lvl" ) {
        $value = int($value);
        if ( $value >= $MeChanUser->lvl ) {
            return
              $s->_n_error( $irc, $Session,
                            "Cannot set lvl greater than yours" );
        } elsif ( $value < 0 ) {
            return $s->_n_error( $irc, $Session, "Cannot set negative lvl" );
        }
    } elsif ( $key eq "auto_mode" ) {
        unless ( $key =~ /^(o|v)$/ ) {
            return
              $s->_n_error( $irc, $Session,
                            "Invalid $key value '$value must be 'o' or 'v'" );
        }
    } else {
        return $s->_n_error( $irc, $Session, "Unknown option $key" );
    }
    $TChanUser->$key($value);
    unless (
        $TChanUser->_update_by(
            { channel_id => $Channel->id, user_id => $TUser->id }
        )
      )
    {
        return $s->_n_error( $irc, $Session,
                             "Cannot set '$key' to '$value'" );
    } else {
        $irc->{Out}->notice('#me#', $Session, "$key as been set to '$value'" );
    }
    return PCI_EAT_ALL;
}

=item channel_user_list

=cut

sub channel_user_list {
    my ( $s, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'channel_user_list';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = App::IRC::Bot::Shoze::Db->new;

    $msg = str_chomp($msg);
    my ( $cmd, $chan, $uname, $lvl ) = split /\s+/, $msg;
    LOG("$cmdname: $chan $uname $lvl");
    unless ( is_valid_chan_name($chan) ) {
        return $s->_n_error( $irc, $Session,
                             "Invalid channel name '$chan'" );
    }
    my ( $type, $channame ) = ( $chan =~ /^(#|&)(.*)$/ );
    my $Channel = $db->NetworkChannels->get_by( $irc->{Network},
                                         { type => $type, name => $channame } );
    unless ($Channel) {
        return $s->_n_error( $irc, $Session,
                             "Channel '$chan' not found" );
    }
    if (     ( $Channel->owner != $Session->user_id )
         and ( $Session->user_lvl < 800 ) )
    {
        return
          $s->_n_error( $irc, $Session,
                        "You can't list user linked to channel '$chan'" );
    }
    my @list = $db->ChannelUsers->list();
    unless (@list) {
        return $s->_n_error( $irc, $Session,
                             "No user linked to '$chan'" );
    }
    my $str = "Listing user linked to $chan ()\n";
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
    $s->_send_lines( $irc, 'notice', '#me#', $Session, split( /\n/, $str ) );
    return PCI_EAT_ALL;
}

=item channel_user_info

=cut

sub channel_user_info {
    my ( $s, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'channel_user_info';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = App::IRC::Bot::Shoze::Db->new;

    $msg = str_chomp($msg);
    my ( $cmd, $chan, $uname ) = split /\s+/, $msg;
    LOG("$cmdname: $chan $uname");
    unless ( is_valid_chan_name($chan) ) {
        return $s->_n_error( $irc, $Session,
                             "Invalid channel name '$chan'" );
    }
    my ( $type, $channame ) = ( $chan =~ /^(#|&)(.*)$/ );
    my $Channel = $db->NetworkChannels->get_by( $irc->{Network},
                                         { type => $type, name => $channame } );
    unless ($Channel) {
        return $s->_n_error( $irc, $Session,
                             "Channel '$chan' not found" );
    }
    if (    ( $Channel->owner != $Session->user_id )
         or ( $Session->user_lvl < 800 ) )
    {
        return
          $s->_n_error( $irc, $Session,
             "You can't get information on user '$uname' for channel '$chan'" );
    }
    my $TUser = $db->Users->get_by( { name => $uname } );
    unless ($TUser) {
        return
          $s->_n_error( $irc, $Session,
                        "Could not find user named '$uname'" );
    }
    my $UserChannel = $db->ChannelUsers->get_by(
                        { channel_id => $Channel->id, user_id => $TUser->id } );
    unless ($UserChannel) {
        return
          $s->_n_error( $irc, $Session,
                        "User 'uname' is not linked to channel '$chan'" );
    }
    my $str .= "["
      . BOTLVL( $TUser->lvl )
      . "] name: "
      . $TUser->name
      . ", lvl: "
      . $UserChannel->lvl;
    $str .= ", auto_mode: " . $UserChannel->auto_mode
      if $UserChannel->auto_mode;
    $irc->{Out}->notice('#me#', $Session, $str );
    return PCI_EAT_ALL;
}

=item channel_user_del

=cut

sub channel_user_del {
    my ( $s, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'channel_user_del';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = App::IRC::Bot::Shoze::Db->new;

    $msg = str_chomp($msg);
    my ( $cmd, $chan, $uname ) = split /\s+/, $msg;
    LOG("$cmdname: $chan $uname");
    unless ( is_valid_chan_name($chan) ) {
        return $s->_n_error( $irc, $Session,
                             "Invalid channel name '$chan'" );
    }
    my ( $type, $channame ) = splitchannel($chan);
    my $Channel = $db->NetworkChannels->get_by( $irc->{Network},
                                         { type => $type, name => $channame } );
    unless ($Channel) {
        return $s->_n_error( $irc, $Session,
                             "Channel '$chan' not found" );
    }
    if (    ( $Channel->owner != $Session->user_id )
         or ( $Session->user_lvl < 800 ) )
    {
        return
          $s->_n_error( $irc, $Session,
                        "You can't delete user linked to channel '$chan'" );
    }
    my $TUser = $db->Users->get_by( { name => $uname } );
    unless ($TUser) {
        return
          $s->_n_error( $irc, $Session,
                        "Could not find user named '$uname'" );
    }
    my $UserChannel = $db->ChannelUsers->get_by(
                        { channel_id => $Channel->id, user_id => $TUser->id } );
    unless ($UserChannel) {
        return
          $s->_n_error( $irc, $Session,
                        "User 'uname' is not linked to channel '$chan'" );
    }
    unless (
             $UserChannel->_delete_by(
                           { channel_id => $Channel->id, user_id => $TUser->id }
             )
      )
    {
        return
          $s->_n_error( $irc, $Session,
            "Could not delete ling between channel '$chan' and user '$uname'" );
    } else {
        $irc->notice('#me#', $Session->nick, 
                     "User '$uname' unlinked from channel '$chan'" );
    }
    return PCI_EAT_ALL;
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
