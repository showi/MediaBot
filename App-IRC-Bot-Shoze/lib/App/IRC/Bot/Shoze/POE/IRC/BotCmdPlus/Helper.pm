package App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Helper;

=head1 NAME

App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Helper - Helper methods 

=cut

=head1 SYNOPSIS
    
This module export subroutines used by the bot

=cut

use strict;
use warnings;

use Carp;
use Exporter;

=head1 EXPORT

=over

=item _n_error 

=item _send_lines 

=item _send_lines_privmsg 

=item _send_lines_notice

=item pretty_help 

=item get_cmd

=item PCI_register 

=item PCI_unregister

=item _register_cmd 

=item _unregister_cmd

=item BOTLVL 

=item CHANLVL 

=item splitchannel 

=item _get_nick 

=item _get_session

=item _add_channel_user 

=item _del_channel_user 

=item can_op 

=item can_voice 

=item _modes 

=item _joinN

=back

=cut
our @ISA = qw(Exporter);

our @MyExport = qw(_n_error _send_lines _send_lines_privmsg _send_lines_notice
  pretty_help get_cmd
  PCI_register PCI_unregister
  _register_cmd _unregister_cmd
  BOTLVL CHANLVL splitchannel _get_nick _get_session
  _add_channel_user _del_channel_user can_op can_voice _modes _join);

our @EXPORT = @MyExport;
our %EXPORT_TAGS = ( ALL => [@MyExport] );

use POE::Component::IRC::Plugin qw(:ALL);
use IRC::Utils qw(:ALL);

use lib qw(../../../../../../../);
use App::IRC::Bot::Shoze::Log;

=head1 SUBROUTINES/METHODS

=over

=item pretty_help

=cut

sub pretty_help {
    my ( $s, $cmd ) = @_;
    croak "Invalid command '$cmd'" unless defined $s->{cmd}->{$cmd};
    return $s->{cmd}->{$cmd}->{help_cmd} . "\n"
      . $s->{cmd}->{$cmd}->{help_description};
}

=item get_cmd

=cut

sub get_cmd {
    my ( $s, $cmd ) = @_;
    croak "Invalid command '$cmd'" unless defined $s->{cmd}->{$cmd};
    return $s->cmd->{$cmd};
}

=item PCI_register

=cut

sub PCI_register {
    my ( $s, $irc ) = splice @_, 0, 2;
    $s->_register_cmd($irc);
    return 1;
}

=item _register_cmd

=cut

sub _register_cmd {
    my ( $s, $irc ) = @_;
    my $C = $irc->plugin_get('BotCmdPlus');
    for my $cmd ( %{ $s->cmd } ) {
        $C->register_command(
            $s, $cmd,
            $s->cmd->{$cmd}->{access},
            $s->cmd->{$cmd}->{lvl}
        );
    }
}

=item PCI_unregister

=cut

sub PCI_unregister {
    my ( $s, $irc ) = splice @_, 0, 2;
    $s->_unregister_cmd($irc);
    return 1;
}

=item _unregister_cmd

=cut

sub _unregister_cmd {
    my ( $s, $irc ) = @_;
    my $C = $irc->plugin_get('BotCmdPlus');
    for my $cmd ( %{ $s->cmd } ) {
        $C->unregister_command($cmd);
    }
}

=item splitchannel

=cut

sub splitchannel {
    return ( undef, undef ) unless $_[0];
    $_[0] =~ /^(#|&)(.*)$/ and do {
        return ($1, $2);
    };
    return undef;
}

=item _send_lines

=cut

sub _send_lines {
    my ( $s, $irc, $what, $who, $where, @lines ) = @_;
    if ($what eq 'notice') {
        $s->_send_lines_notice($irc, $who, $where, @lines);
    } elsif($what eq 'privmsg') {
        $s->_send_lines_privmsg($irc, $who, $where, @lines);
    } else {
        croak "Unknown send type '$what'";
    }
}

=item _send_lines_notice

=cut
sub _send_lines_notice {
   my ( $s, $irc, $who, $where, @lines ) = @_;
   for (@lines) {
        $irc->{Out}->notice($who, $where, $_ );
    }
}

=item _send_lines_privmsg

=cut

sub _send_lines_privmsg {
   my ( $s, $irc, $who, $where, @lines ) = @_;
   for (@lines) {
        $irc->{Out}->privmsg($who, $where, $_ );
    }
}

=item _n_error

=cut

sub _n_error {
    my ( $s, $irc, $where, $msg ) = @_;
    $irc->{Out}->notice('#me#', $where, "Error: $msg" );
    return PCI_EAT_ALL;
}

=item BOTLVL

=cut

sub BOTLVL {
    my $lvl = shift;
    return "owner    " if $lvl >= 1000;
    return "admin    " if $lvl >= 800;
    return "chanowner" if $lvl >= 500;
    return "user     ";
}

=item CHANLVL

=cut

sub CHANLVL {
    my $lvl = shift;
    return "owner" if $lvl >= 500;
    return "admin" if $lvl >= 400;
    return "user " if $lvl >= 200;
}

=item _get_session

=cut

sub _get_session {
    my ( $s, $db, $Nick, $user, $hostname ) = @_;
    croak "Need Db Object as first parameter"
      unless ref($db) =~ /Shoze::Db/;
    croak "Need Nick Object as second parameter"
      unless ref($Nick) =~ /Db::Nicks::Object/;
    my $Session = $db->NetworkSessions->get_by(
        $Nick,
        {
            user     => $user,
            hostname => $hostname
        }
    );
    unless ($Session) {
        my $res = $db->NetworkSessions->create( $Nick, $user, $hostname );
        return $s->_get_session( $db, $Nick, $user, $hostname ) if $res;
        return undef,;
    }
    return $Session;
}

=item _get_nick

Create or return Nick object from database for a given Network

=cut

sub _get_nick {
    my ( $s, $irc, $db, $Network, $nick ) = @_;
    croak "Need Db Object as first parameter"
      unless ref($db) =~ /Shoze::Db/;
    croak "Need Network Object as second parameter"
      unless ref($Network) =~ /Db::Networks::Object/;

    my $Nick = $db->NetworkNicks->get_by( $Network, { nick => $nick } );
    unless ($Nick) {
        my $res = $db->NetworkNicks->create( $Network, $nick );
        return undef unless $res;
        $irc->yield(whois => $nick);
        return $s->_get_nick($irc, $db, $Network, $nick );
    }
    return $Nick;
}


=item _add_channel_user

=cut

sub _add_channel_user {
    my ( $s, $db, $Channel, $Nick, $mode ) = @_;
    croak "Need Channel Object as first parameter"
      unless ref($Channel) =~ /Db::NetworkChannels::Object/;
    croak "Need Nick Object as second parameter"
      unless ref($Nick) =~ /Db::NetworkNicks::Object/;

    my $time = time;
    my $ChanUser =
      $db->NetworkChannelUsers->get_by( $Channel, { nick_id => $Nick->id } );
    return if $ChanUser;
    $ChanUser = new App::IRC::Bot::Shoze::Db::NetworkChannelUsers::Object($db);
    $ChanUser->nick_id( $Nick->id );
    $ChanUser->channel_id( $Channel->id );
    $ChanUser->created_on($time);
    $ChanUser->updated_on($time);
    $ChanUser->mode($mode) if $mode;

    #$ChanUser->session_id( $Session->id ) if $Session;

    unless ( $ChanUser->_create ) {
        WARN(   "Cannot create channel user '"
              . $Nick->nick
              . "' on channel '"
              . $Channel->_usable_name
              . "'" );
    }
}


=item _del_channel_user

=cut

sub _del_channel_user {
    my ( $s, $db, $Channel, $Nick ) = @_;

    croak "Need Db Object as first parameter"
      unless ref($db) =~ /Shoze::Db/;
    croak "Need Channel Object as first parameter"
      unless ref($Channel) =~ /Db::NetworkChannels::Object/;
    croak "Need Nick Object as second parameter"
      unless ref($Nick) =~ /Db::NetworkNicks::Object/;

    my $ChanUser =
      $db->NetworkChannelUsers->get_by( $Channel, { nick_id => $Nick->id } );
    unless ($ChanUser) {
        WARN(   "User '"
              . $Nick->nick
              . "' not found for channel '"
              . $Channel->name
              . "'" );
        return PCI_EAT_NONE;
    }
    unless ( $ChanUser->_delete ) {
        WARN(   "Cannot delete user '"
              . $Nick->nick
              . "' from channel ("
              . $Channel->_usable_name
              . ")" );
        return PCI_EAT_NONE;
    }
    LOG( $Nick->nick . " removed from channel " . $Channel->name );
    return PCI_EAT_NONE;
}


=item _can_op

=cut

sub can_op {
    my ( $s, $irc, $Session, $Channel ) = @_;
    my $db       = App::IRC::Bot::Shoze::Db->new;
    my $hostmask = $Session->get_hostmask;
    my @CAUM =
      $db->ChannelAutoUserMode->list_by( { channel_id => $Channel->id } );
    for (@CAUM) {
        if ( matches_mask( $_->hostmask, $hostmask ) and $_->mode eq 'o' ) {
            return 1;
        }
    }
    unless ( $Session->user_id ) {
        return 0;
    }
    if ( $Session->user_lvl >= 800 ) {
        return 1;
    }
    elsif ( $Channel->owner == $Session->user_id ) {
        return 1;
    }
    else {
        my $ChannelUser = $db->ChannelUsers->get_by(
            { channel_id => $Channel->id, user_id => $Session->user_id } );
        if ( $ChannelUser->lvl >= 400 ) {
            return 1;
        }
    }
    return 0;
}


=item can_voice

=cut

sub can_voice {
    my ( $s, $irc, $Session, $Channel ) = @_;
    my $db       = App::IRC::Bot::Shoze::Db->new;
    my $hostmask = $Session->get_hostmask;
    my @CAUM =
      $db->ChannelAutoUserMode->list_by( { channel_id => $Channel->id } );
    for (@CAUM) {
        if ( matches_mask( $_->hostmask, $hostmask ) and $_->mode =~ /[ov]/ ) {
            return 1;
        }
    }
    unless ( $Session->user_id ) {
        return 0;
    }
    if ( $Session->user_lvl >= 800 ) {
        return 1;
    }
    elsif ( $Channel->owner == $Session->user_id ) {
        return 1;
    }
    else {
        my $ChannelUser = $db->ChannelUsers->get_by(
            { channel_id => $Channel->id, user_id => $Session->user_id } );
        if ( $ChannelUser->lvl >= 300 ) {
            return 1;
        }
    }
    return 0;
}


=item _modes

=cut

sub _modes {
    my ( $s, $irc, $sign, $mode, $Channel, @nicks ) = @_;
    my $max = 6;
    my ( $m, $nicks ) = '';
    my $i = $max;
    for (@nicks) {
        if ( $i < 1 ) {
            $irc->yield( mode => $Channel->_usable_name => "$sign$m $nicks" );
            ( $m, $nicks ) = '';
            $i = $max;
        }
        $m .= $mode;
        $nicks .= " $_";
        $i--;
    }
    if ($m) {
         $irc->yield( mode => $Channel->_usable_name => "$sign$m $nicks" );
    }
}


=item _join

=cut

sub _join {
    my ($s, $irc, $Channel) = @_;
    my $msg = $Channel->_usable_name;
    $msg .= ' ' . $Channel->password if $Channel->password;
    $irc->yield(join => $msg);
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
