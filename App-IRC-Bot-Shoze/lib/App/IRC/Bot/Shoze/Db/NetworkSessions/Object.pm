package App::IRC::Bot::Shoze::Db::NetworkSessions::Object;

use strict;
use warnings;

use Carp;

use lib qw(../../../../../../);
use App::IRC::Bot::Shoze::Class qw(DESTROY);
use App::IRC::Bot::Shoze::Db::SynchObject qw(:ALL);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::String;
use IRC::Utils qw(parse_user);

our $AUTOLOAD;

our %fields = (
    id           => undef,
    nick_id      => undef,
    user         => undef,
    hostname     => undef,
    real         => undef,
    first_access => undef,
    last_access  => undef,
    flood_start  => undef,
    flood_end    => undef,
    flood_numcmd => undef,
    ignore       => undef,
    user_id      => undef,
    updated_on   => undef,
    created_on   => undef,

    _object_name => undef,
    _object_db   => undef,
);

# Constructor
#############
sub new {
    my ( $proto, $object_db ) = @_;
    DEBUG( "Creating new " . __PACKAGE__ , 8);
    croak "No database object passed as first parameter"
      unless ref($object_db);
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    $s->_init_fields;            # DIRTY HACK
    $s->_object_name('network_sessions');
    $s->_object_db($object_db);
    return $s;
}

#sub parse_who {
#    my $s = shift;
#    my ( $nick, $user, $hostname ) = parse_user(shift);
#    $s->nick($nick);
#    $s->user($user);
#    $s->hostname($hostname);
#    return $s;
#}

sub get_hostmask {
    my ($s) = @_;
    return $s->nick . '!' . $s->user . '@' . $s->hostname;
}

1;
