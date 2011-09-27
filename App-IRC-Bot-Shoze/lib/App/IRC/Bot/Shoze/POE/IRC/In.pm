package App::IRC::Bot::Shoze::POE::IRC::In;

=head1 NAME

App::IRC::Bot::Shoze::POE::IRC::In - IRC input event 

=cut

=head1 SYNOPSIS

=cut

use strict;
use warnings;

use Carp;

use POE;

use IRC::Utils ':ALL';

use lib qw(../../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD _get_root DESTROY);
use App::IRC::Bot::Shoze::Constants qw(:ALL);
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Helper qw(:ALL);
use App::IRC::Bot::Shoze::Log;

use Data::Dumper qw(Dumper);

our %fields = ( _parent => undef, _irc => undef );

=head1 SUBROUTINES/METHODS

=over

=item new

=cut

sub new {
    my ( $proto, $parent, $irc ) = @_;
    croak "No parent object passed as first parameter"
      unless ref($parent);
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    $s->_parent($parent);
    $s->_irc($irc);
    return $s;
}

=item user_join

=cut

sub user_join {
    my ( $s, $who, $channel ) = @_;
    my $db = App::IRC::Bot::Shoze::Db->new;

    $s->_irc->{Out}->log( "user_join", $who, $channel, $who );

    my ( $nick, $user, $hostname ) = parse_user($who);
    my ( $type, $channame ) = splitchannel($channel);
    my $Network = $s->_irc->{Network};

    my $Channel = $db->NetworkChannels->get_by(
        $Network,
        {
            type => $type,
            name => $channame
        }
    );
    unless ($Channel) {
        WARN("We are not managing channel '$channel'");
        return 0;
    }
    if ( $nick eq $s->_irc->nick_name ) {
        WARN("We are joining $channel");
        $Channel->bot_joined(1);
        $Channel->mode(undef);
        $Channel->ulimit(undef);
        $Channel->password(undef);
        $Channel->_update();

        $s->_irc->yield( mode => $channel );
        return 0;
    }
    my $Nick = $s->_get_nick( $s->_irc, $db, $Network, $nick );
    unless ($Nick) {
        WARN( "Cannot get nick '$nick' for network '" . $Network->name . "'" );
        return 0;
    }
    $s->_add_channel_user( $db, $Channel, $Nick, "" );
    return 1;
}

=item user_part

=cut

sub user_part {
    my ( $s, $who, $channel ) = @_;
    
    $s->_irc->{Out}->log( "user_part", $who, $channel, $who );
    
    my $db = App::IRC::Bot::Shoze::Db->new;
    my ( $nick, $user, $hostname ) = parse_user($who);
    my $Network = $s->_irc->{Network};
    my $Nick = $s->_get_nick( $s->_irc, $db, $Network, $nick );
    unless ($Nick) {
        WARN( "Could not find nick '$nick' in Network " . $Network->name );
        return 0;
    }
    my ( $chantype, $channame ) = ( $channel =~ /^(#|&)(.*)$/ );
    my $Channel =
      $db->NetworkChannels->get_by( $Network,
        { type => $chantype, name => $channame } );
    unless ($Channel) {
        WARN(
            "Could not find channel '$channel' in Network " . $Network->name );
        return 0;
    }
    if ( $nick eq $s->_irc->nick_name ) {
        WARN("We are leaving $channel");
        $Channel->bot_joined(undef);
        $Channel->_update();

        # return PCI_EAT_NONE;
    }
    $s->_del_channel_user( $db, $Channel, $Nick );
    my @list = $db->NetworkChannelUsers->is_on($Nick);
    if ( @list < 1 ) {
        $Nick->_delete;
    }
    return 1;
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
