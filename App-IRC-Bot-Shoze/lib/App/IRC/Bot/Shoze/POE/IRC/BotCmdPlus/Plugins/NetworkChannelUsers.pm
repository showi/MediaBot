package App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::NetworkChannelUsers;

use strict;
use warnings;

use Carp;
use Encode qw(encode decode);
use Data::Dumper;

use POE::Session;
use POE::Component::IRC::Plugin qw(:ALL);
use IRC::Utils qw(:ALL);

use lib qw(../../../../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::String;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Helper
  qw(_register_cmd _unregister_cmd get_cmd _n_error splitchannel _get_nick _get_session _add_channel_user _del_channel_user);
use App::IRC::Bot::Shoze::Db::NetworkChannelUsers::Object;

our %fields = ( cmd => undef, _parent => undef );

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

sub PCI_register {
    my ( $s, $irc ) = splice @_, 0, 2;
    $irc->plugin_register( $s, 'SERVER',
        qw(324 353 join part quit connected disconnected mode whois) );
    return 1;
}

sub PCI_unregister {
    my ( $s, $irc ) = splice @_, 0, 2;
    return 1;
}

sub _empty {
    my ( $s, $db ) = @_;
    App::IRC::Bot::Shoze::Db->new->ChannelUserList->empty;
}

sub S_connected {
    my ( $s, $irc ) = @_;
    my $db      = App::IRC::Bot::Shoze::Db->new;
    my $Network = $db->Networks->get( $irc->{network_id} );
    unless ($Network) {
        LOG( "Could not found network with id '" . $irc->{network_id} . "'" );
        return PCI_EAT_NONE;
    }
    $db->NetworkNicks->empty($Network);
    return PCI_EAT_NONE;
}

sub S_disconnected {
    my ( $s, $irc ) = @_;
    my $db      = App::IRC::Bot::Shoze::Db->new;
    my $Network = $db->Networks->get( $irc->{network_id} );
    $db->NetworkNicks->empty($Network);
    return PCI_EAT_NONE;
}

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

sub S_part {
    my ( $s, $irc ) = splice @_, 0, 2;
    my ( $who, $channel ) = ( ${ $_[0] }, ${ $_[1] } );
    my $db = App::IRC::Bot::Shoze::Db->new;
    my ( $nick, $user, $hostname ) = parse_user($who);
    my $Network = $irc->{Network};
    my $Nick = $s->_get_nick( $irc, $db, $Network, $nick );
    unless ($Nick) {
        WARN( "Could not find nick '$nick' in Network " . $Network->name );
        return PCI_EAT_NONE;
    }
    my ( $chantype, $channame ) = ( $channel =~ /^(#|&)(.*)$/ );
    my $Channel =
      $db->NetworkChannels->get_by( $Network,
        { type => $chantype, name => $channame } );
    unless ($Channel) {
        WARN(
            "Could not find channel '$channel' in Network " . $Network->name );
        return PCI_EAT_NONE;
    }
    if ( $nick eq $irc->nick_name ) {
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
    return PCI_EAT_NONE;
}

sub S_join {
    my ( $s, $irc ) = splice @_, 0, 2;
    my ( $who, $channel ) = ( ${ $_[0] }, ${ $_[1] } );
    my $db = App::IRC::Bot::Shoze::Db->new;

    my ( $nick, $user, $hostname ) = parse_user($who);

    my ( $type, $channame ) = ( $channel =~ /^(#|&)(.*)$/ );
    my $Network = $irc->{Network};
    unless ($Network) {
        WARN( "Could not found network with id '" . $irc->{network_id} . "'" );
        return PCI_EAT_NONE;
    }
    my $Channel =
      $db->NetworkChannels->get_by( $Network,
        { type => $type, name => $channame } );
    unless ($Channel) {
        WARN("We are not managing channel '$channel'");
        return PCI_EAT_NONE;
    }
    if ( $nick eq $irc->nick_name ) {
        WARN("We are joining $channel");
        $Channel->bot_joined(1);
        $Channel->mode(undef);
        $Channel->ulimit(undef);
        $Channel->password(undef);
        $Channel->_update();

        # Issue mode command on channel
        $irc->yield( mode => $channel );
        return PCI_EAT_NONE;
    }
    my $Nick = $s->_get_nick( $irc, $db, $Network, $nick );
    unless ($Nick) {
        WARN( "Cannot get nick '$nick' for network '" . $Network->name . "'" );
        return PCI_EAT_NONE;
    }
    LOG("Nick $Nick");
    $s->_add_channel_user( $db, $Channel, $Nick, "" );
    return PCI_EAT_NONE;
}

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
        print "Mode $sign$op on $for with arg $arg\n";
        if ( $op =~ /^[ov]$/ ) {
            $s->mode_user( $irc, $Channel, $sign, $op, $arg );
        }
        else {
            $s->mode_channel( $irc, $Channel, $sign, $op, $arg );
        }
    }
    return PCI_EAT_NONE;
}

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
    if ( $sign eq "+" ) {
        $NCU->mode($mode);
    }
    else {
        $NCU->mode(undef);
    }
    return $NCU->_update;
}

#
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
    my $res = $db->NetworkSessions->create(
        $Nick,
        $whois->{user}, $whois->{host}, $whois->{real}
    );
    unless($res) {
        WARN("Cannot create new session for nick " . $whois->{nick});
        return PCI_EAT_NONE;
    }
    return PCI_EAT_NONE;
}

# Names event
sub S_353 {
    my ( $s, $irc ) = splice @_, 0, 2;
    my $db = App::IRC::Bot::Shoze::Db->new;
    print Dumper @_;

    #my @list = @{ ${$_[2] }};
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
            print "User: $nick ($mode)\n";
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

# Mode event
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

1;
