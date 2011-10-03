package App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Sessions;

=head1 NAME

App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Sessions - User tracking

=cut

=head1 SYNOPSIS
    
This module track users

=cut

use strict;
use warnings;

use Carp;

use POE;
use POE::Component::IRC::Plugin qw(:ALL);
use IRC::Utils qw(:ALL);

use Data::Dumper;

use lib qw(../../../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::Db::NetworkSessions::Object;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Helper qw(_get_nick)
  ;    # Must move BotCmd::Helper in Db
our %fields = ( cmd => undef, irc => undef );

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
    return $s;
}

=item PCI_register

=cut

sub PCI_register {
    my ( $self, $irc ) = splice @_, 0, 2;
    $irc->plugin_register( $self, 'SERVER',
        qw(msg public ctcp_ping nick connected) );
    $self->irc($irc);
    return 1;
}

=item PCI_unregister

=cut

sub PCI_unregister {
    my ( $self, $irc ) = splice @_, 0, 2;
    return 1;
}

=item S_connected

=cut

sub S_connected {
    my ( $self, $irc ) = splice @_, 0, 2;
    my $db      = App::IRC::Bot::Shoze::Db->new;

    $db->NetworkChannels->clear_joined($irc->{Network});
    $db->NetworkSessions->clear($irc->{Network});
    return PCI_EAT_NONE;
}

=item destroy_session

=cut

sub destroy_session {
    my ( $self, $irc ) = splice @_, 0, 2;
    my ( $who, $msg ) = ( ${ $_[0] }, ${ $_[1] } );
    my $db = App::IRC::Bot::Shoze::Db->new;

    my $OldSession =
      App::IRC::Bot::Shoze::Db::NetworkSessions::Object->new($db)
      ->parse_who($who);
    my $NewSession = $db->Sessions->get_by(
        {
            nick     => $OldSession->nick,
            user     => $OldSession->user,
            hostname => $OldSession->hostname
        }
    );
    $db->Sessions->delete( $NewSession->id );
}

=item S_nick

=cut

sub S_nick {
    my ( $self, $irc ) = splice @_, 0, 2;
    my ( $who, $msg ) = ( ${ $_[0] }, ${ $_[1] } );
    my $db = App::IRC::Bot::Shoze::Db->new;
    my $OldSession =
      App::IRC::Bot::Shoze::Db::NetworkSessions::Object->new($db)
      ->parse_who($who);
    my $NewSession = $db->Sessions->get_by(
        {
            user     => $OldSession->user,
            hostname => $OldSession->hostname
        }
    );
    $NewSession->nick($msg);
    $db->Sessions->update($NewSession);
}

=item _default

=cut

sub _default {
    my ( $s, $irc, $event ) = splice @_, 0, 3;
    my $db = App::IRC::Bot::Shoze::Db->new;

    LOG( __PACKAGE__ . "  $event" );
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );

    $db->NetworkSessions->delete_idle;

    my ( $nick, $user, $hostname ) = parse_user($who);
    my $Nick = $s->_get_nick( $irc, $db, $irc->{Network}, $nick );
    unless ($Nick) {
        WARN( "Could not create nick '" . $Nick->nick . "'" );
        return PCI_EAT_NONE;
    }
    my $Session = $db->NetworkSessions->get_by(
        $Nick,
        {
            user     => $user,
            hostname => $hostname
        }
    );
    unless ( defined $Session ) {
        LOG("Creating session for $who");
        $db->NetworkSessions->create( $Nick, $user, $hostname );
    }
    else {
        LOG("Updating session");
        $db->NetworkSessions->update($Session);
        if ( $Session->ignore ) {
            LOG( "Ignoring " . $Session->_pretty );
            return PCI_EAT_ALL;
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
