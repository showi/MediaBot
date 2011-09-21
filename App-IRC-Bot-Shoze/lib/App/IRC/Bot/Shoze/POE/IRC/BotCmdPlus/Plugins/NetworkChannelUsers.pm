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
        qw(324 353 join part quit connected disconnected) );

    #$s->_register_cmd($irc);
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
    my $db = App::IRC::Bot::Shoze::Db->new;
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
    unless($Network) {
        WARN("Could not find Network object");
        return PCI_EAT_NONE;
    }
    my $Nick = $db->NetworkNicks->get_by($Network, { nick => $nick } );
    unless($Nick) {
        WARN("Could not find nick '$nick' Object for Network '".$Network->name."'");
        return PCI_EAT_NONE;
    }
    $db->NetworkNicks->del($Network, $Nick);
    return PCI_EAT_NONE;
}

sub S_part {
    my ( $s, $irc ) = splice @_, 0, 2;
    my ( $who, $channel ) = ( ${ $_[0] }, ${ $_[1] } );
    my $db = App::IRC::Bot::Shoze::Db->new;
    my ( $nick, $user, $hostname ) = parse_user($who);
    my $Network = $irc->{Network};
    my $Nick = $s->_get_nick($db, $Network, $nick);
    unless($Nick) {
        WARN("Could not find nick '$nick' in Network " . $Network->name);
        return PCI_EAT_NONE;
    }
    my ($chantype, $channame) = ($channel =~ /^(#|&)(.*)$/);
    my $Channel = $db->NetworkChannels->get_by($Network, {type => $chantype, name => $channame});
    unless($Channel) {
        WARN("Could not find channel '$channel' in Network " . $Network->name);
        return PCI_EAT_NONE;
    }
    if ($nick eq $irc->nick_name) {
        WARN("We are leaving $channel");
        $Channel->bot_joined(undef);
        $Channel->_update();
       # return PCI_EAT_NONE;
    }
    $s->_del_channel_user( $db, $Channel, $Nick);
    my @list = $db->NetworkChannelUsers->is_on($Nick);
    if (@list < 1) {
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
    if ($nick eq $irc->nick_name) {
        WARN("We are joining $channel");
        $Channel->bot_joined(1);
        $Channel->_update();
        return PCI_EAT_NONE;
    }
    my $Nick = $s->_get_nick( $db, $Network, $nick );
    unless ($Nick) {
        WARN( "Cannot get nick '$nick' for network '" . $Network->name . "'" );
        return PCI_EAT_NONE;
    }
    LOG("Nick $Nick");
    $s->_add_channel_user( $db, $Channel, $Nick, "" );
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
        my $Nick = $s->_get_nick( $db, $Network, $nick );
        unless ($Nick) {
            WARN(   "Cannot get nick '$nick' for network '"
                  . $Network->name
                  . "'" );
            return PCI_EAT_NONE;
        }

        #    my $Session = $db->NetworkSessions->get_by(nick_id => $Nick->id);
        $s->_add_channel_user( $db, $Channel, $Nick, $mode );
    }
    return PCI_EAT_NONE;
}

# Mode event
#sub S_324 {
#    my ( $self, $irc ) = splice @_, 0, 2;
#    my ( $who, $where ) = ( ${ $_[0] }, ${ $_[1] } );
#    LOG("Event[324] '$who', '$where '");
#
#    $where =~ /^([#|&][\w\d_-]+)\s+\+(([^\s]+)(\s+.*)?)?$/ or do {
#        DEBUG("Invalid 324 EVENT\n");
#        return PCI_EAT_NONE;
#    };
#    my ( $chan, $mode, @args ) = ( $1, $3, split( /\s+/, str_chomp($4) ) );
#    LOG("Channel $1 have mode $2");
#    my $db = App::IRC::Bot::Shoze::Db->new;
#    my ( $type, $channame ) = ( $chan =~ /^(#|&)(.*)$/ );
#    my $Channel = $db->NetworkChannels->get_by($irc->{Network},  { type => $type, name => $channame } );
#    return PCI_EAT_NONE unless $Channel;
#    return PCI_EAT_NONE unless $Channel->auto_mode;
#
#    my $hrm  = parse_mode_line($mode);
#    my $iarg = 0;
#    my ( $chanmode, $chanmodeparam, $chanargs );
#    for ( 0 .. $#{ $hrm->{modes} } ) {
#        my $index = $_;
#        my ( $osign, $omode ) = ( $hrm->{modes}->[$index] =~ /([+-])([\w])/ );
#        if ( $omode !~ /^[lk]$/ ) {
#            $chanmode .= "$osign$omode";
#        }
#        elsif ( $omode eq 'k' ) {
#            if ( $osign eq '+' ) {
#                if ( !$Channel->password ) {
#                    $chanmodeparam .= "-k";
#                    $chanargs .= $args[$iarg] . " ";
#                }
#                else {
#                    if ( $Channel->password ne $args[$iarg] ) {
#                        $chanmodeparam .= "-k+k";
#                        $chanargs .=
#                          $args[$iarg] . " " . $Channel->password . " ";
#                    }
#                }
#            }
#            $iarg++;
#        }
#        elsif ( $omode eq 'l' ) {
#            if ( $osign eq '+' ) {
#                if ( !$Channel->ulimit ) {
#                    $chanmodeparam .= "-l";
#
#                    #$chanargs .= 0 . " "
#                }
#                else {
#                    if ( $Channel->ulimit ne $args[$iarg] ) {
#                        $chanmodeparam .= "+l";
#                        $chanargs .= $Channel->ulimit . " ";
#                    }
#                }
#            }
#            $iarg++;
#        }
#    }
#    $chanmode = unparse_mode_line($chanmode);
#    print "Want to apply '$chanmode'\n";
#    print "And  $chanmodeparam with $chanargs\n" if $chanmodeparam;
#    my $newmode = "+" . $Channel->mode;
#    my $newargs = "";
#    if ( $Channel->password ) {
#        $newmode .= "k";
#        $newargs .= $Channel->password . " ";
#    }
#    if ( $Channel->ulimit ) {
#        $newmode .= "l";
#        $newargs .= $Channel->ulimit . " ";
#    }
#    print "Enforce mode: $newmode with params $newargs\n";
#    my $rmode = gen_mode_change( $chanmode, $newmode );
#    $rmode = $chanmodeparam . $rmode if $chanmodeparam;
#    LOG("MODE CHANGE $newmode / $rmode");
#    return PCI_EAT_NONE if ( !$rmode );
#
#    #or ( $chanmode eq $newmode ) );
#    $irc->yield( 'mode' => $chan => $rmode => "$chanargs$newargs" );
#
#    return PCI_EAT_ALL;
#}

1;
