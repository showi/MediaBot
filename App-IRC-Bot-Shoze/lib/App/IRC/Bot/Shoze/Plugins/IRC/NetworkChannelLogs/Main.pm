package App::IRC::Bot::Shoze::Plugins::IRC::NetworkChannelLogs::Main;

=head1 NAME

App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::NetworkChannelLogs - NetworkChannelLogs plugin

=cut

=head1 SYNOPSIS

This plugin allow administrator to log channel

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
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Helper
  qw(get_cmd _register_cmd _unregister_cmd _n_error splitchannel _send_lines _send_lines_notice);

our %fields = ( cmd => undef, logs => undef );

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
           'channel_log_list' => {
                                   access           => 'msg',
                                   lvl              => 800,
                                   help_cmd         => '!channel.log.list',
                                   help_description => 'List logged channels',
           },
           'channel_log_add' => {
               access   => 'msg',
               lvl      => 800,
               help_cmd => '!channel.log.add <channel src> <log type> <target>',
               help_description => 'Add logged channel',
           },
        }
    );
    $s->logs( {} );
    return $s;
}

=item PCI_register

=cut

sub PCI_register {
    my ( $s, $irc ) = splice @_, 0, 2;
    $s->_register_cmd($irc);
    $s->_register_event($irc);
    return 1;
}

=item _register_event

=cut

sub _register_event {
    my ( $s, $irc ) = @_;
    $irc->plugin_register( $s, 'SERVER', qw(public) );
    $s->logs( {} );
    my $db   = App::IRC::Bot::Shoze::Db->new;
    my @logs = $db->NetworkChannelLogs->list();
    unless (@logs) {
        $s->logs(undef);
        return;
    }
    for (@logs) {
        next unless ( $_->active );
        my $nid = $irc->{Network}->id;
        next
          if (    $_->src_network_channel_network_id != $nid
               or $_->target_network_channel_network_id != $nid );
        my $src_channel =
          $_->src_network_channel_type . $_->src_network_channel_name;
        LOG( "Channel log, src: " . $src_channel );
        my $d = {
                  type   => $_->type,
                  target => $_->target_network_channel_type
                    . $_->target_network_channel_name,
        };
        unless ( defined $s->logs->{$src_channel} ) {
            $s->logs->{$src_channel} = ();
        }
        push @{ $s->logs->{$src_channel} }, $d;
    }
}

=item PCI_unregister

=cut

sub PCI_unregister {
    my ( $s, $irc ) = splice @_, 0, 2;
    $s->_unregister_cmd($irc);
    $s->logs(undef);
    return 1;
}

=item _default

=cut

sub _default {
    my ( $s, $irc, $event ) = splice @_, 0, 3;
    unless ( $s->logs ) {
        LOG("No channel logs");
        return PCI_EAT_NONE;
    }
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $srcchannel = $where->[0];
    unless ( $s->logs->{$srcchannel} ) {
        LOG("Channel $srcchannel is not logged");
        return PCI_EAT_NONE;
    }
    my $db = App::IRC::Bot::Shoze::Db->new;
    my ( $type, $name ) = splitchannel($srcchannel);
    for ( @{ $s->logs->{$srcchannel} } ) {
        my $Channel = $db->NetworkChannels->get_by( $irc->{Network},
                                             { type => $type, name => $name } );
        unless ($Channel) {
            WARN("Cannot get log channel $srcchannel");
            next;
        }
        unless ( $Channel->bot_joined ) {
            WARN("We do not log to channel that we don't have joined");
            next;
        }

        if ( $_->{type} eq "irc" ) {
            $irc->{Out}->privmsg( '#me#', $_->{target},
                                  "[" . time . "][$srcchannel][$who] $msg" );
        }
    }
    return PCI_EAT_NONE;
}

=item channel_log_list

=cut

sub channel_log_list {
    my ( $s, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'channel_log_list';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = App::IRC::Bot::Shoze::Db->new;

    my @list = $db->NetworkChannelLogs->list();
    unless (@list) {
        return
          $s->_n_error( $irc, $Session->nick,
                       "No channel log for 'network'" . $irc->{Network}->name );
    }
    my $str = "Listing log for network " . $irc->{Network}->name . "\n";
    for my $l (@list) {
        my $nid = $irc->{Network}->id;
        next
          if (     $l->src_network_channel_network_id != $nid
               and $l->target_network_channel_network_id != $nid );
        $str .= ( $l->active ? "[On ]" : "[Off]" );
        $str .=
          $l->src_network_channel_type . $l->src_network_channel_name . " => ";
        $str .=
          $l->target_network_channel_type . $l->target_network_channel_name;
        $str .= " (via " . $l->type . ")";
        $str = $str .= "\n";
    }
    $s->_send_lines( $irc, 'notice', '#me#', $Session, split( /\n/, $str ) );
    return PCI_EAT_ALL;
}

=item channel_log_add

=cut

sub channel_log_add {
    my ( $s, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'channel_log_add';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = App::IRC::Bot::Shoze::Db->new;

    my ( $cmd, $chansrc, $logtype, $target ) = ( split( /\s+/, $msg ) );
    return
      $s->_n_error( $irc, $Session,
                    "Invalid syntax: " . $PCMD->{help_description} )
      unless ( $chansrc || $logtype || $target );

    LOG("Want to log $chansrc to $target ($logtype)");
    my @authtype = qw(irc db file ws);
    return
      $s->_n_error(
                    $irc,
                    $Session,
                    "Invalid logging facility '$logtype' must be one of "
                      . join( ", ", @authtype )
      ) unless ( grep( /$logtype/, @authtype ) );
    my ( $stype, $sname ) = splitchannel($chansrc);
    my $SChan = $db->NetworkChannels->get_by( $irc->{Network},
                                           { type => $stype, name => $sname } );
    return
      $s->_n_error( $irc, $Session,
                    "Cannot log channel '$chansrc': not managed" )
      unless $SChan;

    if ( $logtype eq "irc" ) {
        return
          $s->_n_error( $irc, $Session,
                        "Cannot log channel to the the same channel ..." )
          if ( $chansrc eq $target );
        my ( $ttype, $tname ) = splitchannel($target);
        my $TChan = $db->NetworkChannels->get_by( $irc->{Network},
                                           { type => $ttype, name => $tname } );
        return
          $s->_n_error( $irc, $Session,
                        "Target '$target' is not a managed channel" )
          unless $TChan;
        my $Log =
          $db->NetworkChannelLogs->get_by(
                                           {
                                             src_channel_id    => $SChan->id,
                                             target_channel_id => $TChan->id,
                                             type              => $logtype
                                           }
          );
        return
          $s->_n_error( $irc, $Session,
                      "Channel '$chansrc' already logged to '$target' via IRC" )
          if $Log;
        my $ret =
          $db->NetworkChannelLogs->create( $SChan, $logtype, $TChan,
                                           $Session->user_id );
        unless ($ret) {
            return
              $s->_n_error( $irc, $Session,
                        "Cannot log channel '$chansrc'  to '$target' via IRC" );
        } else {
            $irc->notice( '#me#', $Session->nick,
                 "[$cmdname] Logging channel '$chansrc' to '$target' via IRC" );
        }
    } else {
        return
          $s->_n_error( $irc, $Session,
                        "Log facility '$logtype' not supported" );
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
