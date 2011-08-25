package MediaBot::IRC::User;
use strict;
use warnings;

use Carp;

use POE::Session;

use lib qw(../../);
use MediaBot::Class qw(AUTOLOAD DESTROY);
use MediaBot::String;
use MediaBot::Log;

our $AUTOLOAD;

our %fields = (
    _parent => undef,
    nick    => undef,
    ident   => undef,
    host    => undef,
);

# Constructor
#############
sub new {
    my ($proto) = @_;
    DEBUG( "Creating new " . __PACKAGE__ );

    #croak "No parent specified" unless ref $parent;
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );

    #$s->_parent($parent);
    return $s;
}

sub _cleanstr {
    return str_asciionly( str_chomp(shift) );
}

sub parse_event {
    my $s = shift;
    my ($who) = $_[ARG0];
    my ( $nick,  $idhost ) = split /!/, $who;
    my ( $ident, $host )   = split /@/, $idhost;
    $s->nick( esc_nick($nick) );
    $s->ident( esc_ident($ident) );
    $s->host( esc_host($host) );
}

sub pretty_print {
    my $s = shift;
    return $s->nick . " " . $s->ident . "@" . $s->host;
}

1;
