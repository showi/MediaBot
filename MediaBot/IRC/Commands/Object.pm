package MediaBot::IRC::Commands::Object;

use strict;
use warnings;

use Carp;
use Switch;

use lib qw(../../../);
use MediaBot::Class qw(AUTOLOAD DESTROY);
use MediaBot::Log;
use MediaBot::Constants;

use POE::Session;

our $AUTOLOAD;

our %fields = (
    type           => undef,
    User           => undef,
    cmd            => undef,
    cmd_parameters => undef,
    msg            => undef,
    args           => undef,
);

# Constructor
#############
sub new {
    my ($proto) = @_;
    DEBUG( "Creating new " . __PACKAGE__ );
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    return $s;
}

sub type {
    my ( $s, $type ) = @_;
    return $s->{type} unless $type;
    switch ($type) {
        case IRCCMD_TYPE_PRV { $s->{type} = $type; }
        case IRCCMD_TYPE_PUB { $s->{type} = $type; }
        croak "Undefined IRC TYPE '$type'";
    };
}

1;
