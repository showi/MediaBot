package MediaBot::IRC::Commands::Plugins::User;

use strict;
use warnings;

use Carp;

use lib qw(../../../../);
use MediaBot::Class qw(AUTOLOAD DESTROY);
use MediaBot::Log;
use MediaBot::Constants;

use POE::Session;

our $AUTOLOAD;

our %fields = (
    _parent        => undef,
    cmd            => undef,
    lvl            => undef,
    description    => undef,
    on             => undef,
    registered_cmd => undef,
);

# Constructor
#############
sub new {
    my ( $proto, $parent ) = @_;
    DEBUG( "Creating new " . __PACKAGE__ );
    croak "No parent specified" unless ref $parent;
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    $s->_parent($parent);
    $s->cmd('version');
    my @cmds = qw(login logout);
    $s->registered_cmd( \@cmds );
    return $s;
}

sub login {
    my ( $s, $CO ) = @_;
    my ( $sender, $where, $what ) = @{ $CO->args }[ SENDER, ARG1 .. ARG2 ];
    my $nick = $CO->User->nick;
    my $channel = $where;
    my $irc = $sender->get_heap();
    
    if ($CO->type == IRCCMD_TYPE_PUB) {
          $irc->yield( privmsg => $nick =>
          "You have issued login command on channel, your credentials may have been compromised!" );
        return;
    }
    $irc->yield( privmsg => $nick =>
          "You are trying to login!" );
    return;
}

sub logout {
    my ( $s, $CO ) = @_;
    my ( $sender, $where, $what ) = @{ $CO->args }[ SENDER, ARG1 .. ARG2 ];
    my $nick = $CO->User->nick;
    my $channel = $where;
    my $irc = $sender->get_heap();
    
    if ($CO->type == IRCCMD_TYPE_PUB) {
        return;
    }
    $irc->yield( privmsg => $nick =>
          "You are trying to logout!" );
    return;
}

1;
