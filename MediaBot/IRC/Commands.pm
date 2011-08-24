package MediaBot::IRC::Commands;
use strict;
use warnings;

use Carp;
use Exporter;
use POE::Session;

use lib qw(../../);
use MediaBot::Class qw(AUTOLOAD DESTROY LOG _get_root);
use MediaBot::String;

our @ISA    = qw(Exporter);
our @EXPORT = qw(irc_botcmd_version irc_botcmd_register);

our $AUTOLOAD;

our %fields = ( 
    _parent => undef,
    cmd_prefix => undef,
);

# Constructor
#############
sub new {
    my ( $proto, $parent ) = @_;
    print "Creating new " . __PACKAGE__ . "\n";
    croak "No parent specified" unless ref $parent;
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    $s->_parent($parent);
    my $cmd_prefix = $s->_get_root->Config->bot->{cmd_prefix};
    croak "Unconfigured or bad cmd_prefix in bot.yaml config" 
        unless $cmd_prefix =~ /^[!.]$/;
    $s->cmd_prefix($cmd_prefix);
    return $s;
}

1;

sub _cleanstr {
    return str_asciionly( str_chomp(shift) );
}

sub dispatch {
    my $s     = shift;
    my $type  = shift;
    
    my $cmd_prefix = $s->cmd_prefix;
    return unless $_[ARG2] =~ /^$cmd_prefix[a-z0-9_-]+/;
    my $what = substr($_[ARG2], 1);
    print " what: $what\n";
    my ($who) = $_[ARG0];
    my ( $nick,  $idhost ) = split /!/, $who;
    my ( $ident, $host )   = split /@/, $idhost;
    $nick  = _cleanstr($nick);
    $ident = _cleanstr($ident);
    $host  = _cleanstr($host);
    print "Dispatching $type command for user: $nick [$ident] @ $host\n";
    my $US = $s->_parent->Sessions->add( $nick, $ident, $host );
    unless ($US) {
        print "Cannot create user session, returning!\n";
        return 1;
    } 
    if ($US->ignore) {
        print "Ignored user\n";
        return 2;
    }
    print "Dispatching command\n";
    return 0;
}

#
#sub irc_botcmd_version {
#	my ( $sender, $who, $where, $what ) = @_[ SENDER, ARG0 .. ARG2 ];
#	my $nick     = ( split /!/, $who )[0];
#	my $channel  = $where;
#	my ($kernel) = $_[KERNEL];
#	my $irc      = $sender->get_heap();      # obtain the poco's object
#    $irc->yield( privmsg => $channel => "I'm $MediaBot::PROGRAMNAME ($MediaBot::VERSION" );
#	return 0;
#}
#
#sub irc_botcmd_register {
#	my ( $sender, $who, $where, $what, $user, $password ) = @_[ SENDER, ARG0 .. ARG4 ];
#	die "boom";
#	my $nick     = ( split /!/, $who )[0];
#	my $channel  = $where;
#	my ($kernel) = $_[KERNEL];
#	my $irc      = $sender->get_heap();      # obtain the poco's object
#	LOG("$user/password");
#    if ($channel eq $nick) {
#    	$irc->yield( privmsg => $nick => "You cannot register on channel, everybody have seen your password..." );
#    	return 0;
#    }
#    $irc->yield( privmsg => $nick => "I'm trying to register you with name $user" );
#	return 0;
#}
#
#1;
