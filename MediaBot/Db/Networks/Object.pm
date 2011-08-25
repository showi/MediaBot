package MediaBot::Db::Networks::Object;

use strict;
use warnings;

use Carp;

use lib qw(../../../);
use MediaBot::Class qw(AUTOLOAD DESTROY);

our $AUTOLOAD;

our %fields = (
	id => undef,
	name => undef,
);

# Constructor
#############
sub new {
	my ( $proto) = @_;
	DEBUG("Creating new " . __PACKAGE__);
	my $class = ref($proto) || $proto;
	my $s = {
		_permitted => \%fields,
		%fields,
	};
	bless( $s, $class );
	return $s;
}

1;