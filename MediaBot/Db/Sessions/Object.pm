package MediaBot::Db::Sessions::Object;

use strict;
use warnings;

use Carp;

use lib qw(../../../);
use MediaBot::Class qw(AUTOLOAD DESTROY LOG);

our $AUTOLOAD;

our %fields = (
	id => undef,
	nick => undef,
	ident => undef,
	host => undef,
	first_request => undef,
	flood_start => undef,
	flood_end => undef,
	flood_numcmd => undef,
	ignore => undef,
);

# Constructor
#############
sub new {
	my ( $proto) = @_;
	print "Creating new " . __PACKAGE__ . "\n";
	my $class = ref($proto) || $proto;
	my $s = {
		_permitted => \%fields,
		%fields,
	};
	bless( $s, $class );
	return $s;
}

1;