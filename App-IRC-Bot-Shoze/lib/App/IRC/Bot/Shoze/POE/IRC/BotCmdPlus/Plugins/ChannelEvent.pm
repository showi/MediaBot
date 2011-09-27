package App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::ChannelEvent;

=head1 NAME

App::IRC::Bot::Shoze::Db::ChannelEvent - ChannelEvent plugin

=cut

=head1 SYNOPSIS

=cut

use strict;
use warnings;

use Carp;

use POE;
use POE::Component::IRC::Plugin qw(:ALL);
use IRC::Utils qw(:ALL);

use Data::Dumper;

use lib qw(../../../../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::String;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Helper qw(_join);

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
    $irc->plugin_register( $self, 'SERVER', qw(324 join part invite) );
    $self->irc($irc);
    return 1;
}

=item PCI_unregister

=cut

sub PCI_unregister {
    my ( $self, $irc ) = splice @_, 0, 2;
    return 1;
}

=item S_324

# 324 RPL_CHANNELMODEIS
# "<canal> <mode> <paramètres de mode >"

=cut

sub S_324 {
    my ( $self, $irc ) = splice @_, 0, 2;
    my ( $who, $where ) = ( ${ $_[0] }, ${ $_[1] } );
    LOG("Event[324] '$who', '$where '");

    $where =~ /^([#|&][\w\d_-]+)\s+\+(([^\s]+)(\s+.*)?)?$/ or do {
        DEBUG("Invalid 324 EVENT\n");
        return PCI_EAT_NONE;
    };
    my ( $chan, $mode, @args ) = ( $1, $3, split( /\s+/, str_chomp($4) ) );
    LOG("Channel $1 have mode $2");
    my $db = App::IRC::Bot::Shoze::Db->new;
    my ( $type, $channame ) = ( $chan =~ /^(#|&)(.*)$/ );
    my $Channel = $db->NetworkChannels->get_by( $irc->{Network},
                                         { type => $type, name => $channame } );
    return PCI_EAT_NONE unless $Channel;
    return PCI_EAT_NONE unless $Channel->auto_mode;

    my $hrm  = parse_mode_line($mode);
    my $iarg = 0;
    my ( $chanmode, $chanmodeparam, $chanargs );
    for ( 0 .. $#{ $hrm->{modes} } ) {
        my $index = $_;
        my ( $osign, $omode ) = ( $hrm->{modes}->[$index] =~ /([+-])([\w])/ );
        if ( $omode !~ /^[lk]$/ ) {
            $chanmode .= "$osign$omode";
        } elsif ( $omode eq 'k' ) {
            if ( $osign eq '+' ) {
                if ( !$Channel->password ) {
                    $chanmodeparam .= "-k";
                    $chanargs .= $args[$iarg] . " ";
                } else {
                    if ( $Channel->password ne $args[$iarg] ) {
                        $chanmodeparam .= "-k+k";
                        $chanargs .=
                          $args[$iarg] . " " . $Channel->password . " ";
                    }
                }
            }
            $iarg++;
        } elsif ( $omode eq 'l' ) {
            if ( $osign eq '+' ) {
                if ( !$Channel->ulimit ) {
                    $chanmodeparam .= "-l";

                    #$chanargs .= 0 . " "
                } else {
                    if ( $Channel->ulimit ne $args[$iarg] ) {
                        $chanmodeparam .= "+l";
                        $chanargs .= $Channel->ulimit . " ";
                    }
                }
            }
            $iarg++;
        }
    }
    $chanmode = unparse_mode_line($chanmode);

    #    print "Want to apply '$chanmode'\n";
    #    print "And  $chanmodeparam with $chanargs\n" if $chanmodeparam;
    my $newmode = "+" . $Channel->mode;
    my $newargs = "";
    if ( $Channel->password ) {
        $newmode .= "k";
        $newargs .= $Channel->password . " ";
    }
    if ( $Channel->ulimit ) {
        $newmode .= "l";
        $newargs .= $Channel->ulimit . " ";
    }

    #    print "Enforce mode: $newmode with params $newargs\n";
    my $rmode = gen_mode_change( $chanmode, $newmode );
    $rmode = $chanmodeparam . $rmode if $chanmodeparam;
    LOG("MODE CHANGE $newmode / $rmode");
    return PCI_EAT_NONE if ( !$rmode );
    $irc->yield( 'mode' => $chan => $rmode => "$chanargs$newargs" );
    return PCI_EAT_ALL;
}

=item S_join

=cut

sub S_join {
    my ( $self, $irc ) = splice @_, 0, 2;
    my ( $who, $where ) = ( ${ $_[0] }, ${ $_[1] } );
    my ( $nick, $user, $hostmask ) = parse_user($who);
    if ( $irc->nick_name eq $nick ) {
        my $db = App::IRC::Bot::Shoze::Db->new;
        my ( $type, $channame ) = ( $where =~ /^(#|&)(.*)$/ );
        my $Channel = $db->NetworkChannels->get_by(
            $irc->{Network},
            { type => $type, name => $channame } );
        return PCI_EAT_NONE unless $Channel;
        $Channel->bot_joined(1);
        $Channel->bot_mode(undef);
        $Channel->_update;
        LOG("We have joined channel $where");
    }
    return PCI_EAT_NONE;
}

=item S_invite

=cut

sub S_invite {
    my ( $s, $irc ) = splice @_, 0, 2;
    my $db = App::IRC::Bot::Shoze::Db->new;

    my ( $who, $where ) = ( ${ $_[0] }, ${ $_[1] } );
    my ( $type, $channame ) = ( $where =~ /^(#|&)(.*)$/ );
    my $Channel = $db->NetworkChannels->get_by( $irc->{Network},
                                         { type => $type, name => $channame } );
    return PCI_EAT_NONE unless $Channel;
    return PCI_EAT_NONE if $Channel->bot_joined;

    my ( $nick, $user, $hostname ) = parse_user($who);
    my $Session = $db->Sessions->get_extended( $nick, $user, $hostname );

    unless ($Session) {
        $irc->{Out}->privmsg('#me#', $nick, "# Who are you!" );
        return PCI_EAT_ALL;
    }
    my $User;
    if ( $Session->user_id ) {
        $User = $db->Users->get( $Session->user_id );
    }
    LOG("We receive an invite on $where!");
    $s->_join( $irc, $Channel );
    return PCI_EAT_NONE;
}

=item S_part

=cut

sub S_part {
    my ( $self, $irc ) = splice @_, 0, 2;
    my ( $who, $where ) = ( ${ $_[0] }, ${ $_[1] } );
    my ( $nick, $user, $hostname ) = parse_user($who);
    my $db = App::IRC::Bot::Shoze::Db->new;

    if ( $irc->nick_name eq $nick ) {
        my ( $type, $channame ) = ( $where =~ /^(#|&)(.*)$/ );
        my $Channel = $db->NetworkChannels->get_by( $irc->{Network},
                                         { type => $type, name => $channame } );
        unless ($Channel) {
            WARN("Do not find channel '$where' in database");
            return PCI_EAT_ALL;
        }
        $Channel->bot_joined(undef);
        unless ( $Channel->_update ) {
            WARN("Cannot unset bot_joined on channel $where");
        }
        LOG("We have leaved channel $where");
    } else {
        my $NewSession = $db->Sessions->get_by(
                      { nick => $nick, user => $user, hostname => $hostname } );
        $NewSession->_delete if $NewSession;
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
