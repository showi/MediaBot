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
    my $tmpuser = new MediaBot::IRC::User();
    $tmpuser->parse_event(@_);
    my $US = $s->_parent->Sessions->add( $tmpuser->nick, $tmpuser->ident, $tmpuser->host );
    unless ($US) {
        LOG("Cannot create user session, returning!");
        return undef;
    }
    my $db = $s->_get_root->Db->Users;
    $db->delete_idle();
    if ( $US->ignore ) {
        LOG("Ignore user " . $tmpuser->pretty_print);
        return undef;
    }
    my $user = $db->get_byidenthost($US->ident, $US->host);
    if ($user and $user->logged_on) {
       $db->last_access($user->id);
       $user->nick($tmpuser->nick);
    }
    LOG("User can communicate with me: " . $tmpuser->pretty_print);
    return $user || $tmpuser;
}

1;
