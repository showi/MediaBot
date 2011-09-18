package App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Helper;

use strict;
use warnings;

use Carp;
use Exporter;

use POE::Component::IRC::Plugin qw(:ALL);

use lib qw(../../../../../../../);
use App::IRC::Bot::Shoze::Log;

our @ISA = qw(Exporter);

our @MyExport = qw(_n_error _send_lines
  pretty_help get_cmd
  PCI_register PCI_unregister
  _register_cmd _unregister_cmd
  BOTLVL CHANLVL splitchannel _get_nick _get_session
  _add_channel_user _del_channel_user);

#our @EXPORT_OK = @MyExport;
our @EXPORT = @MyExport;
our %EXPORT_TAGS = ( ALL => [@MyExport] );

sub pretty_help {
    my ( $s, $cmd ) = @_;
    croak "Invalid command '$cmd'" unless defined $s->{cmd}->{$cmd};
    return $s->{cmd}->{$cmd}->{help_cmd} . "\n"
      . $s->{cmd}->{$cmd}->{help_description};
}

sub get_cmd {
    my ( $s, $cmd ) = @_;
    croak "Invalid command '$cmd'" unless defined $s->{cmd}->{$cmd};
    return $s->cmd->{$cmd};
}

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

sub PCI_register {
    my ( $s, $irc ) = splice @_, 0, 2;
    $s->_register_cmd($irc);
    return 1;
}

sub _unregister_cmd {
    my ( $s, $irc ) = @_;
    my $C = $irc->plugin_get('BotCmdPlus');
    for my $cmd ( %{ $s->cmd } ) {
        $C->unregister_command($cmd);
    }
}

sub PCI_unregister {
    my ( $s, $irc ) = splice @_, 0, 2;
    $s->_unregister_cmd($irc);
    return 1;
}

sub splitchannel {
    return ( undef, undef ) unless $_[0];
    return ( $_[0] =~ /^(#|&)(.*)$/ );
}

sub _send_lines {
    my ( $s, $irc, $what, $where, @lines ) = @_;
    for (@lines) {
        $irc->yield( $what => $where => $_ );
    }
}

sub _n_error {
    my ( $s, $irc, $who, $msg ) = @_;
    $irc->yield( "notice" => $who => "Error: $msg" );
    return PCI_EAT_ALL;
}

sub BOTLVL {
    my $lvl = shift;
    return "owner    " if $lvl >= 1000;
    return "admin    " if $lvl >= 800;
    return "chanowner" if $lvl >= 500;
    return "user     ";
}

sub CHANLVL {
    my $lvl = shift;
    return "owner" if $lvl >= 500;
    return "admin" if $lvl >= 400;
    return "user " if $lvl >= 200;
}

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

# Create or return Nick object from database for a given Network
sub _get_nick {
    my ( $s, $db, $Network, $nick ) = @_;
    croak "Need Db Object as first parameter"
      unless ref($db) =~ /Shoze::Db/;
    croak "Need Network Object as second parameter"
      unless ref($Network) =~ /Db::Networks::Object/;

    my $Nick = $db->NetworkNicks->get_by( $Network, { nick => $nick } );
    unless ($Nick) {
        my $res = $db->NetworkNicks->create( $Network, $nick );
        return $s->_get_nick( $db, $Network, $nick ) if $res;
        return undef;
    }
    return $Nick;
}

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

1;
