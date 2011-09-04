package App::IRC::Bot::Shoze::Db::Networks::Object;

use strict;
use warnings;
use Carp;

use lib qw(../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY);
use App::IRC::Bot::Shoze::Log;

our $AUTOLOAD;

our %fields = (
    id   => undef,
    name => undef,
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

1;
