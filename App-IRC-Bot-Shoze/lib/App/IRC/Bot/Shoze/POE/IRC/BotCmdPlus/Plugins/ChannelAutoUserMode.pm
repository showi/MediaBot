package App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::ChannelAutoUserMode;

use strict;
use warnings;

use Carp;
use Encode qw(encode decode);
use Data::Dumper;

use POE::Component::IRC::Plugin qw(:ALL);
use IRC::Utils qw(:ALL);

use lib qw(../../../../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::String;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Helper
  qw(_register_cmd _unregister_cmd get_cmd _n_error);

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
    $irc->plugin_register( $s, 'SERVER', qw(join) );
    return 1;
}

sub PCI_unregister {
    my ( $s, $irc ) = splice @_, 0, 2;
    return 1;
}

sub S_join {
    my ( $s, $irc ) = splice @_, 0, 2;
    my ( $who, $channel ) = ( ${ $_[0] }, ${ $_[1] } );
    my $db = App::IRC::Bot::Shoze::Db->new;

    my ( $nick, $user, $hostname ) = parse_user($who);
    my ( $type, $channame ) = ( $channel =~ /^(#|&)(.*)$/ );
    my $Channel = $db->Channels->get_by( { type => $type, name => $channame } );
    unless ($Channel) {
        LOG("We are not managing channel '$channel'");
        return PCI_EAT_NONE;
    }
    my @AutoMode =
      $db->ChannelUserAutoMode->list_by( { channel_id => $Channel->id, } );
    for (@AutoMode) {
        if ( matches_mask( $_->hostmask, $who ) ) {
            LOG( "AutoMode match hostmask '" . $_->hostmask . "'" );
            if ( $_->action eq 'o' ) {
                LOG("Need to op $who");
                $irc->yield( 'mode' => "$channel +o $nick" );
                last;
            }
            elsif ( $_->action eq 'v' ) {
                LOG("Need to voice $who");
                $irc->yield( 'mode' => "$channel +v $nick" );
                last;
            }
            elsif ( $_->action eq 'b' ) {
                LOG("Need to ban $who");
            }
            else {
                WARN( "Invalid AutoMode '" . $_->action . "'" );
            }
        }
    }
    return PCI_EAT_NONE;
}

1;
