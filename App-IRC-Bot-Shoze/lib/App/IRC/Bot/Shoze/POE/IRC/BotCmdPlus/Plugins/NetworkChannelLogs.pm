###############################################################################
# Plugins:: NetworkChannelLogs
#---------------
#
# This plugin allow administrator to log channel
#
###############################################################################
package App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::NetworkChannelLogs;

use strict;
use warnings;

use Carp;

use POE::Component::IRC::Plugin qw(:ALL);
use IRC::Utils qw(:ALL);

use lib qw(../../../../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::String;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Helper
  qw(get_cmd _register_cmd _unregister_cmd _n_error splitchannel _send_lines);

our %fields = ( cmd => undef, logs => undef );

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
                access => 'msg',
                lvl    => 800,
                help_cmd =>
                  '!channel.log.add <channel src> <log type> <target>',
                help_description => 'Add logged channel',
            },
        }
    );
    $s->logs( {} );
    return $s;
}

sub PCI_register {
    my ( $s, $irc ) = splice @_, 0, 2;
    $s->_register_cmd($irc);
    $s->_register_event($irc);
    return 1;
}

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

sub PCI_unregister {
    my ( $s, $irc ) = splice @_, 0, 2;
    $s->_unregister_cmd($irc);
    $s->logs(undef);
    return 1;
}

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
        if ( $_->{type} eq "irc" ) {
            $irc->yield(
                privmsg => $_->{target} => "[" . time . "][$srcchannel][$who] $msg" );
        }
    }
}

sub channel_log_list {
    my ( $s, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'channel_log_list';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = App::IRC::Bot::Shoze::Db->new;

    #my ( $cmd, $chansrc, $logtype, $target ) = ( split( /\s+/, $msg ) );
    my @list = $db->NetworkChannelLogs->list();
    unless (@list) {
        return $s->_n_error( $irc, $Session->nick,
            "No channel log for 'network'" . $irc->{Network}->name );
    }
    my $str = "Listing log for network " . $irc->{Network}->name . "\n";
    for my $l (@list) {
        $str .= ( $l->active ? "[On ]" : "[Off]" );
        $str .=
          $l->src_network_channel_type . $l->src_network_channel_name . " => ";
        $str .=
          $l->target_network_channel_type . $l->target_network_channel_name;
        $str .= " (via " . $l->type . ")";
        $str .= $str .= "\n";
    }
    $s->_send_lines( $irc, 'notice', $Session->nick, split( /\n/, $str ) );
    return PCI_EAT_ALL;
}

sub channel_log_add {
    my ( $s, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'channel_log_add';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = App::IRC::Bot::Shoze::Db->new;

    my ( $cmd, $chansrc, $logtype, $target ) = ( split( /\s+/, $msg ) );
    return $s->_n_error( $irc, $Session->nick,
        "Invalid syntax: " . $PCMD->{help_description} )
      unless ( $chansrc || $logtype || $target );

    LOG("Want to log $chansrc to $target ($logtype)");
    my @authtype = qw(irc db file ws);
    return $s->_n_error( $irc, $Session->nick,
        "Invalid logging facility '$logtype' must be one of "
          . join( ", ", @authtype ) )
      unless ( grep( /$logtype/, @authtype ) );
    my ( $stype, $sname ) = splitchannel($chansrc);
    my $SChan =
      $db->NetworkChannels->get_by( $irc->{Network},
        { type => $stype, name => $sname } );
    return $s->_n_error( $irc, $Session->nick,
        "Cannot log channel '$chansrc': not managed" )
      unless $SChan;

    if ( $logtype eq "irc" ) {
        return $s->_n_error( $irc, $Session->nick,
            "Cannot log channel to the the same channel ..." )
          if ( $chansrc eq $target );
        my ( $ttype, $tname ) = splitchannel($target);
        my $TChan =
          $db->NetworkChannels->get_by( $irc->{Network},
            { type => $ttype, name => $tname } );
        return $s->_n_error( $irc, $Session->nick,
            "Target '$target' is not a managed channel" )
          unless $TChan;
        my $Log = $db->NetworkChannelLogs->get_by(
            {
                src_channel_id    => $SChan->id,
                target_channel_id => $TChan->id,
                type              => $logtype
            }
        );
        return $s->_n_error( $irc, $Session->nick,
            "Channel '$chansrc' already logged to '$target' via IRC" )
          if $Log;
        my $ret =
          $db->NetworkChannelLogs->create( $SChan, $logtype, $TChan,
            $Session->user_id );
        unless ($ret) {
            return $s->_n_error( $irc, $Session->nick,
                "Cannot log channel '$chansrc'  to '$target' via IRC" );
        }
        else {
            $irc->yield( notice => $Session->nick =>
                  "[$cmdname] Logging channel '$chansrc' to '$target' via IRC"
            );
        }
    }
    else {
        return $s->_n_error( $irc, $Session->nick,
            "Log facility '$logtype' not supported" );
    }
    return PCI_EAT_ALL;
}

1;
