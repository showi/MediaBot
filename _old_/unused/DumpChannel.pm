package App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::DumpChannel;

use strict;
use warnings;

use Carp;
use Encode qw(encode decode);
use Data::Dumper;

use POE::Component::IRC::Plugin qw(:ALL);
use IRC::Utils qw(:ALL);

use lib qw(../../../../../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::String;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Helper
  qw(_register_cmd _unregister_cmd get_cmd _n_error);

our %fields = ( cmd => undef, _parent => undef);

#
# #channel_name => {
#   file => 'file'
#   bot => {
#    
#  } 
# }
#
#
#

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
    $s->_register_cmd($irc);
    return 1;
}

sub PCI_unregister {
    my ( $s, $irc ) = splice @_, 0, 2;
    $s->_unregister_cmd($irc);
    return 1;
}

sub _add {
    my ($s, $chansrc, $chandest, $method, $link) = @_;
}

1;