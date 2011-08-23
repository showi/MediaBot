package MediaBot::IRC;

use strict;
use warnings;

use Carp;

use lib qw(..);
use MediaBot::Class qw(AUTOLOAD DESTROY);

our $AUTOLOAD;

my %fields = (

);

sub new {
	my ($proto) = @_;
	print "Creating new " . __PACKAGE__ . "\n";
	my $class = ref($proto) || $proto;
	my $s = {
		_permitted => \%fields,
		%fields,
	};
	bless( $s, $class );
	$s->read('irc');
	$s->read('db');
	return $s;
}

1;
