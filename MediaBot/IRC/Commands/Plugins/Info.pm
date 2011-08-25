package MediaBot::IRC::Commands::Plugins::Info;

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
    my @cmds = qw(version test);
    $s->registered_cmd( \@cmds );
    return $s;
}

sub version {
    my ( $s, $CO ) = @_;
    my ( $sender, $where, $what ) = @{ $CO->args }[ SENDER, ARG1 .. ARG2 ];
    my $nick = $CO->User->nick;
    my $channel = $where;
    $where = $channel;
    $where = $nick if ( $CO->type == IRCCMD_TYPE_PRV );
    my $irc = $sender->get_heap();
    $irc->yield( ctcp => $where =>
          "ACTION I'm $MediaBot::PROGRAMNAME ($MediaBot::VERSION)" );
    return;
}

sub test {
    my ( $s, $CO ) = @_;
    my ( $sender, $where, $what ) = @{ $CO->args }[ SENDER, ARG1 .. ARG2 ];
    my $nick = $CO->User->nick;
    my $channel = $where;
    $where = $channel;
    $where = $nick if ( $CO->type == IRCCMD_TYPE_PRV );
    my $irc = $sender->get_heap();
    $irc->yield( ctcp => $where => "ACTION Wanna test my kick?" );
    return;
}


#$irc->yield( privmsg => $where => "I'm $MediaBot::PROGRAMNAME ($MediaBot::VERSION)" );
#$irc->yield( notice => $where => "I'm $MediaBot::PROGRAMNAME ($MediaBot::VERSION)" );

1;
