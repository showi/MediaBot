package MediaBot::Db::Sessions::Object;

use strict;
use warnings;

use Carp;

use lib qw(../../../);
use MediaBot::Class qw(AUTOLOAD DESTROY);
use MediaBot::Log;
use MediaBot::String;
use IRC::Utils qw(parse_user);

our $AUTOLOAD;

our %fields = (
    id           => undef,
    nick         => undef,
    user         => undef,
    hostname     => undef,
    first_access => undef,
    last_access  => undef,
    flood_start  => undef,
    flood_end    => undef,
    flood_numcmd => undef,
    ignore       => undef,
    user_id      => undef,
);

# Constructor
#############
sub new {
    my ($proto) = @_;
    DEBUG( "Creating new " . __PACKAGE__, 5);
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    return $s;
}

sub parse_who {
    my $s = shift;
    my ( $nick, $user, $hostname ) = parse_user(shift);
    $s->nick($nick);
    $s->user($user);
    $s->hostname($hostname);
    return $s;
}

sub sid {
    my $s = shift;
    return $s->user . "@" . $s->hostname;
}

sub pretty {
    my $s = shift;
    return $s->user . "!" . $s->user . "@" . $s->hostname;
}

1;
