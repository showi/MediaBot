package App::IRC::Bot::Shoze::POE::IRC::Out;

use strict;
use warnings;

use Carp;

use POE;

use IRC::Utils ':ALL';

use lib qw(../../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD _get_root DESTROY);
use App::IRC::Bot::Shoze::Constants qw(:ALL);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::Db;

use Data::Dumper qw(Dumper);

our %fields = ( _parent => undef, _irc => undef );

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

############
# Messages #
############

sub send_msg {
    my ($s, $type, $who, $target, $msg) = @_;
    my $dest = $target;
    $s->log( $type, $who, $target, $msg );
    if (ref($target) =~ /NetworkSessions/) {
        LOG("NetworkSessions object");
        if ($target->user_id and $target->user_lvl >= 800) {
            $s->_irc->call( $type => $target->nick => $msg );
            return;
        } 
        $dest = $target->nick;
    }
    $s->_irc->yield( $type => $dest => $msg );
}

sub notice {
    my ( $s, $who, $target, $msg ) = @_;
    $s->send_msg('notice', $who, $target, $msg);
    #$s->_irc->yield( notice => $target => $msg );
}

sub privmsg {
    my ( $s, $who, $target, $msg ) = @_;
    $s->send_msg('privmsg', $who, $target, $msg);
#    $s->log( 'privmsg', $who, $target, $msg );
#    $s->_irc->yield( privmsg => $target => $msg );
}

sub ctcp_action {
    my ( $s, $who, $target, $msg ) = @_;
    #$s->send_msg('notice', $who, $target, $msg);
    $s->log( 'ctcp_action', $who, $target, $msg );
    $s->_irc->yield( ctcp => $target => "ACTION $msg" );
}

##############
#
##############

sub log {
    my ( $s, $type, $who, $target, $msg ) = @_;
    my $db = App::IRC::Bot::Shoze::Db->new;
    my @T;
    if ( ref($target) =~ /^ARRAY/ ) {
        @T = @{$target};
    }
    else {
        push @T, $target;
    }
    my $time = time;
    for (@T) {
        $db->BotLogs->create( $s->_irc->{Network}->id, $type, $who, $_, $msg )
          ;
         # $s->_irc->call( privmsg => "#teuk" => "[$time][$type][$_][$who] $msg" );
    }
}

sub join {
    my ( $s, $who, $where, $Channel ) = @_;
    my $msg = $Channel->_usable_name;
    $msg .= ' ' . $Channel->password if $Channel->password;
    $s->log( 'join', $who, $where, $Channel->_usable_name );
    $s->_irc->yield( join => $msg );
}

sub part {
    my ( $s, $who, $where, $Channel ) = @_;
    my $msg = $Channel->_usable_name;
    $s->log( 'part', $who, $where, $Channel->_usable_name );
    $s->_irc->yield( part => $Channel->_usable_name );
}

1;
