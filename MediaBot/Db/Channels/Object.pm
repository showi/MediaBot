package MediaBot::Db::Channels::Object;

use strict;
use warnings;

use Carp;

use lib qw(../../../);
use MediaBot::Class qw(AUTOLOAD DESTROY);
use MediaBot::Log;

our $AUTOLOAD;

our %fields = (
    id        => undef,
    type     => undef,
    name      => undef,
    owner    => undef,
    topic => undef,
    auto_topic => undef,
    auto_voice => undef,
    auto_op => undef,
    active => undef,
    created_on => undef,
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

# Usable name, concatenate type and name
sub usable_name {
    my $s = shift;
    return $s->type . $s->name;
}
1;
