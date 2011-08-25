package MediaBot::IRC::UserRequestFilter;
use strict;
use warnings;

use Carp;

use lib qw(../../);
use MediaBot::Class qw(AUTOLOAD DESTROY _get_root);
use MediaBot::Log;
use MediaBot::Constants;
use MediaBot::IRC::User;
our $AUTOLOAD;

our %fields = (
    _parent => undef,

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
    return $s;
}

sub run {
    my ($s) = shift;
    my $user = new MediaBot::IRC::User();
    $user->parse_event(@_);
    my $US = $s->_parent->Sessions->add( $user->nick, $user->ident, $user->host );
    unless ($US) {
        LOG("Cannot create user session, returning!");
        return undef;
    }
    if ( $US->ignore ) {
        LOG("Ignore user " . $user->pretty_print);
        return undef;
    }
    LOG("User can communicate with me: " . $user->pretty_print);
    return $user;
}

1;
