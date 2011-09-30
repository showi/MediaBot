package App::IRC::Bot::Shoze::Plugins::IRC::UserTracking::Main;

=head1 NAME

App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::NetworkChannelUsers - NetworkChannelUsers plugin

=cut

=head1 SYNOPSIS

=cut

use strict;
use warnings;

use Carp;
use Encode qw(encode decode);
use Data::Dumper;

use POE::Session;
use POE::Component::IRC::Plugin qw(:ALL);
use IRC::Utils qw(:ALL);

use lib qw(../../../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::String;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Helper
  qw(_register_cmd _unregister_cmd get_cmd _n_error splitchannel _get_nick _get_session _add_channel_user _del_channel_user);
use App::IRC::Bot::Shoze::Db::NetworkChannelUsers::Object;

our %fields = ( cmd => undef, _parent => undef );

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
    $s->_parent($parent);
    return $s;
}

=item PCI_register

=cut

sub PCI_register {
    my ( $s, $irc ) = splice @_, 0, 2;
    $irc->plugin_register( $s, 'SERVER',
        qw(324 353 join part quit connected disconnected mode whois registered) );
    return 1;
}

=item PCI_unregister

=cut

sub PCI_unregister {
    my ( $s, $irc ) = splice @_, 0, 2;
    return 1;
}

=item _empty

=cut

sub _empty {
    my ( $s, $db ) = @_;
    App::IRC::Bot::Shoze::Db->new->ChannelUserList->empty;
}

=item S_registered

=cut

sub S_registered {
    my ( $s, $irc ) = @_;
    print "Registered: " . $irc->session_id . "\n";
}

=item S_connected

=cut

sub S_connected {
    my ( $s, $irc ) = @_;
    my $db      = App::IRC::Bot::Shoze::Db->new;
    $db->NetworkNicks->empty($irc->{Network});
    return PCI_EAT_NONE;
}

=item S_disconnected

=cut

sub S_disconnected {
    my ( $s, $irc ) = @_;
    my $db      = App::IRC::Bot::Shoze::Db->new;
    $db->NetworkNicks->empty($irc->{Network});
    return PCI_EAT_NONE;
}

=item S_quit

=cut

sub S_quit {
    my ( $s, $irc ) = splice @_, 0, 2;
    my ($who) = ( ${ $_[0] }, ${ $_[1] } );
    my $db = App::IRC::Bot::Shoze::Db->new;
    my ( $nick, $user, $hostname ) = parse_user($who);
    my $Network = $irc->{Network};
    unless ($Network) {
        WARN("Could not find Network object");
        return PCI_EAT_NONE;
    }
    my $Nick = $db->NetworkNicks->get_by( $Network, { nick => $nick } );
    unless ($Nick) {
        WARN(   "Could not find nick '$nick' Object for Network '"
              . $Network->name
              . "'" );
        return PCI_EAT_NONE;
    }
    $db->NetworkNicks->del( $Network, $Nick );
    return PCI_EAT_NONE;
}

=item S_part

=cut

sub S_part {
    my ( $s, $irc ) = splice @_, 0, 2;
    $irc->{In}->user_part(${ $_[0] }, ${ $_[1] });
    return PCI_EAT_NONE;
}

=item S_join

=cut

sub S_join {
    my ( $s, $irc ) = splice @_, 0, 2;
    $irc->{In}->user_join(${ $_[0] }, ${ $_[1] });
    return PCI_EAT_NONE;
}

=item S_mode

=cut

sub S_mode {
    my ( $s, $irc ) = splice @_, 0, 2;
    my ( $who, $for, $mode ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my @args = splice( @_, 3, $#_ ) if defined $_[3];

    #@args =  @{ $_[3]} if (defined $_[3] and ref($_[3]) =~ /^SCALAR/);

    unless ( $for =~ /^(&|#)([\w\d_-]+)/ ) {
        WARN( "User mode changed is not supported by " . __PACKAGE__ );
        return PCI_EAT_NONE;
    }

    my $db = App::IRC::Bot::Shoze::Db->new;
    my ( $type, $name ) = splitchannel($for);
    my $Channel =
      $db->NetworkChannels->get_by( $irc->{Network},
        { type => $type, name => $name } );
    unless ($Channel) {
        WARN("$for is not a managed channel!");
        return PCI_EAT_NONE;
    }
    $mode = unparse_mode_line($mode);
    LOG("Mode change: $who / $for / $mode / @args");

    my ( $sign, $op );
    my $p   = 1;
    my $len = length($mode);
    for ( my $p = 0 ; $p < $len ; $p++ ) {
        my $tok = substr( $mode, $p, 1 );
        if ( $tok =~ /^(\+|-)$/ ) {
            $sign = $tok;
            next;
        }
        else {
            $op = $tok;
        }
        my $arg = "";
        if ( $op =~ /^[ovk]$/ ) {
            $arg = ${ shift @args };
        }
        elsif ( $op eq 'l' and $sign eq '+' ) {
            $arg = ${ shift @args };
        }
        if ( $op =~ /^[ov]$/ ) {
            $s->mode_user( $irc, $Channel, $sign, $op, $arg );
        }
        else {
            $s->mode_channel( $irc, $Channel, $sign, $op, $arg );
        }
    }
    return PCI_EAT_NONE;
}

=item mode_channel

=cut

sub mode_channel {
    my ( $s, $irc, $Channel, $sign, $mode, $arg ) = @_;

    if ( $mode eq 'k' ) {
        if ( $sign eq '+' ) {
            $Channel->password($arg);
        }
        else {
            $Channel->password(undef);
        }
        return $Channel->_update();
    }
    elsif ( $mode eq 'l' ) {
        if ( $sign eq '+' ) {
            $Channel->ulimit($arg);
        }
        else {
            $Channel->ulimit(undef);
        }
        return $Channel->_update();
    }

    my $cmode = $Channel->mode;
    if ( $sign eq '+' ) {
        if ( $cmode !~ /$mode/ ) {
            $cmode .= $mode;
        }
    }
    else {
        $cmode =~ s/$mode//;
    }
    $Channel->mode($cmode);
    return $Channel->_update;
}

=item mode_user

=cut

sub mode_user {
    my ( $s, $irc, $Channel, $sign, $mode, $nick ) = @_;
    my $db = App::IRC::Bot::Shoze::Db->new;

    my $Nick = $db->NetworkNicks->get_by( $irc->{Network}, { nick => $nick } );
    unless ($Nick) {
        WARN("nick $nick not found");
        return 0;
    }
    my $NCU =
      $db->NetworkChannelUsers->get_by( $Channel, { nick_id => $Nick->id } );
    unless ($NCU) {
        WARN(   "NetworkChannelUser not found on channel '"
              . $Channel->_usable_name
              . "' for nick '"
              . $Nick->nick
              . "'" );
        return 0;
    }
    if ( $sign eq "+" ) {
        $NCU->mode($mode);
    }
    else {
        $NCU->mode(undef);
    }
    return $NCU->_update;
}

=item S_whois

=cut

sub S_whois {
    my ( $s, $irc ) = splice @_, 0, 2;
    my $whois = ${ $_[0] };
    my $db    = App::IRC::Bot::Shoze::Db->new;
    print Dumper $whois;
    my $Nick =
      $db->NetworkNicks->get_by( $irc->{Network}, { nick => $whois->{nick} } );
    unless ($Nick) {
        WARN( "nick " . $whois->{nick} . " not found" );
        return 0;
    }
    my $Session = $db->NetworkSessions->get_by(
        $Nick,
        {
            user     => $whois->{user},
            hostname => $whois->{host},
        }
    );
    return PCI_EAT_NONE if $Session;
    my $res =
      $db->NetworkSessions->create( $Nick, $whois->{user}, $whois->{host},
        $whois->{real} );
    unless ($res) {
        WARN( "Cannot create new session for nick " . $whois->{nick} );
        return PCI_EAT_NONE;
    }
    return PCI_EAT_NONE;
}

=item S_353

=cut

sub S_353 {
    my ( $s, $irc ) = splice @_, 0, 2;
    my $db = App::IRC::Bot::Shoze::Db->new;
    #print Dumper @_;

    my $Network = $irc->{Network};
    unless ($Network) {
        LOG( "Could not found network with id '" . $irc->{network_id} . "'" );
        return PCI_EAT_NONE;
    }
    my ( $channame, @users ) =
      ( ${ $_[2] }->[1], split( /\s+/, ${ $_[2] }->[2] ) );
    my ( $type, $name ) = splitchannel($channame);
    my $Channel =
      $db->NetworkChannels->get_by( $Network,
        { type => $type, name => $name } );
    unless ($Channel) {
        WARN("Unmanaged channel '$channame'");
        return PCI_EAT_NONE;
    }
    LOG("Listing user on $channame");
    for (@users) {
        my ( $mode, $nick ) = (/^(@|\+)?(.*)$/);
        if ($mode) {
            if    ( $mode eq '@' ) { $mode = 'o' }
            elsif ( $mode eq '+' ) { $mode = 'v' }
            else {
                WARN("Unknow mode set it to none");
                $mode = "";
            }
        }
        my $Nick = $s->_get_nick( $irc, $db, $Network, $nick );
        unless ($Nick) {
            WARN(   "Cannot get nick '$nick' for network '"
                  . $Network->name
                  . "'" );
            next;
        }
        $s->_add_channel_user( $db, $Channel, $Nick, $mode );
    }
    return PCI_EAT_NONE;
}

=item S_324

=cut

sub S_324 {
    my ( $self, $irc ) = splice @_, 0, 2;
    my ( $who, $where ) = ( ${ $_[0] }, ${ $_[1] } );
    my $db = App::IRC::Bot::Shoze::Db->new;

    LOG("Event[324] '$who', '$where'");
    my ( $channel, $mode, @args ) = split( /\s+/, $where );
    my ( $ctype, $cname ) = splitchannel($channel);
    LOG("Channel $channel have mode $mode");
    my $Channel =
      $db->NetworkChannels->get_by( $irc->{Network},
        { type => $ctype, name => $cname } );
    unless ($Channel) {
        WARN("Channel $channel is not managed");
        return PCI_EAT_NONE;
    }
    $mode =~ s/^\+(.*)$/$1/;
    my $rmode = '';
    for ( my $p = 0 ; $p < length($mode) ; $p++ ) {
        my $tok = substr( $mode, $p, 1 );
        if ( $tok !~ /[kl]/ ) {
            $rmode .= $tok;
            next;
        }
        else {
            if ( $tok eq 'k' ) {
                $Channel->password( shift @args );
            }
            elsif ( $tok eq 'l' ) {
                $Channel->ulimit( shift @args );
            }
        }
    }
    $Channel->mode($rmode);
    $Channel->_update;
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
