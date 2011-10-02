package App::IRC::Bot::Shoze::Plugins::IRC::AutoUserMode::Main;

=head1 NAME

App::IRC::Bot::Shoze::Db::ChannelAutoUserMode - ChannelAutoUserMode plugin

=cut

=head1 SYNOPSIS

    Automatically op, voice, kick, ban users based on their hostmask
=cut

use strict;
use warnings;

use Carp;
use Encode qw(encode decode);
use Data::Dumper;

use POE::Component::IRC::Plugin qw(:ALL);
use IRC::Utils qw(:ALL);

use lib qw(../../../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::String;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Helper
  qw(_register_cmd _register_database _unregister_database _unregister_cmd get_cmd _n_error splitchannel);

use App::IRC::Bot::Shoze::Plugins::IRC::AutoUserMode::Db::Object;

our %fields = ( cmd => undef, _parent => undef, database => undef );

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
    my $argument_filter = qr/^[\s\w\d+~!@*\._-]+$/;
    bless( $s, $class );
    $s->cmd(
             {
               'auto_umode_add' => {
                         access   => 'msg',
                         lvl      => 800,
                         help_cmd => '!auto.umode.add <hostmask> <(+|-)[ovbk]>',
                         help_description => 'Global user auto mode add/set',
                         argument_filter  => $argument_filter,
               },
               'auto_umode_del' => {
                         access   => 'msg',
                         lvl      => 800,
                         help_cmd => '!auto.umode.del <hostmask> <(+|-)[ovbk]>',
                         help_description => 'Global user auto mode delete',
                         argument_filter  => $argument_filter,
               },
             }
    );
    my @db;
    push @db,
      {
        type => 'IRC',
        name => 'AutoUserMode',
      };
    $s->database( \@db );
    return $s;
}

=item PCI_register

=cut

sub PCI_register {
    my ( $s, $irc ) = splice @_, 0, 2;
    $s->_register_cmd($irc);
    $s->_register_database($irc);
    $irc->plugin_register( $s, 'SERVER', qw(join) );
    return 1;
}

=item PCI_unregister

=cut

sub PCI_unregister {
    my ( $s, $irc ) = splice @_, 0, 2;
    $s->_unregister_cmd($irc);
    $s->_unregister_database($irc);
    return 1;
}

=item auto_umode_add

=cut

sub auto_umode_add {
    my ( $s, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'auto_umode_add';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = App::IRC::Bot::Shoze::Db->new;

    my ( $cmd, $hostmask, $mode ) = split( /\s+/, $msg );
    $hostmask = normalize_mask($hostmask);
    $mode =~ /^(\+|-)([ovbk])$/ or do {
        return
          $s->_n_error( $irc, $Session,
                        "Invalid mode '$mode', format (+|-)[ovbk]" );
    };
    my $AM =
      $db->Plugins->AutoUserMode->get_by(
                                          {
                                            hostmask   => $hostmask,
                                            channel_id => undef
                                          }
      );
    if ($AM) {
        if ( $AM->mode eq $mode ) {
            return
              $s->_n_error( $irc, $Session,
                            "Hostmask '$hostmask' already have mode '$mode'" );
        } else {
            $AM->mode($mode);
            unless ( $AM->_update ) {
                $s->_n_error( $irc, $Session,
                        "Cannot update mode '$mode' for hostmask '$hostmask'" );
            }
        }
    }
    $AM =
      App::IRC::Bot::Shoze::Plugins::IRC::AutoUserMode::Db::Object->new($db);
    $AM->hostmask($hostmask);
    $AM->mode($mode);
    unless ( $AM->_create ) {
        $s->_n_error( $irc, $Session,
                      "Cannot create mode '$mode' for hostmask '$hostmask'" );
    }
    $irc->{Out}
      ->notice( '#me#', $Session, "Mode '$mode' set to hostmask '$hostmask'" );
    return PCI_EAT_ALL;
}

=item auto_umode_add

=cut

sub auto_umode_del {
    my ( $s, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'auto_umode_del';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = App::IRC::Bot::Shoze::Db->new;

    my ( $cmd, $hostmask, $mode ) = split( /\s+/, $msg );
    $hostmask = normalize_mask($hostmask);
    $mode =~ /^(\+|-)([ovbk])$/ or do {
        return
          $s->_n_error( $irc, $Session,
                        "Invalid mode '$mode', format (+|-)[ovbk]" );
    };
    my $AM =
      $db->Plugins->AutoUserMode->get_by(
                                          {
                                            hostmask   => $hostmask,
                                            channel_id => undef,
                                            mode       => $mode
                                          }
      );
    unless ($AM) {
        return
          $s->_n_error( $irc, $Session,
                        "Mode '$mode' for hostmask '$hostmask' not found" );
    }
    unless ( $AM->_delete ) {
        return $s->_n_error(
            $irc,
            $Session,
            "Cannot delete mode '$mode' for hostmask '$hostmask'"
        );
    }
    $irc->{Out}
      ->notice( '#me#', $Session, "Mode '$mode' for hostmask '$hostmask' deleted." );
    return PCI_EAT_ALL;
}

=item S_join

=cut

sub S_join {
    my ( $s, $irc ) = splice @_, 0, 2;
    my ( $who, $channel ) = ( ${ $_[0] }, ${ $_[1] } );
    my $db = App::IRC::Bot::Shoze::Db->new;

    my ( $nick, $user, $hostname ) = parse_user($who);
    my ( $type, $channame ) = splitchannel($channel);
    my $Channel = $db->NetworkChannels->get_by( $irc->{Network},
                                         { type => $type, name => $channame } );
    unless ($Channel) {
        LOG("We are not managing channel '$channel'");
        return PCI_EAT_NONE;
    }
    print "Chanel: " . $Channel->id . "\n";
    my @GAutoMode =
      $db->Plugins->AutoUserMode->list_by( { channel_id => undef } );
    my @LAutoMode =
      $db->Plugins->AutoUserMode->list_by( { channel_id => $Channel->id } );
    my @AutoMode = ( @LAutoMode, @GAutoMode );
    for (@AutoMode) {
        print "automode: channel_id: "
          . $_->channel_id . " / "
          . $_->hostmask . " / "
          . $who . "\n";
        if ( matches_mask( $_->hostmask, $who ) ) {
            LOG( "AutoMode match hostmask '" . $_->hostmask . "'" );
            if ( $_->mode eq '+o' ) {
                LOG("Need to op $who");
                $irc->yield( 'mode' => "$channel +o $nick" );
                last;
            } elsif ( $_->mode eq '+v' ) {
                LOG("Need to voice $who");
                $irc->yield( 'mode' => "$channel +v $nick" );
                last;
            } elsif ( $_->mode eq '+b' ) {
                LOG("Need to ban $who");
            } else {
                WARN( "Invalid AutoMode '" . $_->mode . "'" );
            }
        }
    }
    return PCI_EAT_NONE;
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
