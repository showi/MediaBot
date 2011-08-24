package MediaBot::IRC::Commands::Object;

use strict;
use warnings;

use Carp;
use Switch;

use lib qw(../../../);
use MediaBot::Class qw(AUTOLOAD DESTROY LOG);
use MediaBot::Constants;

use POE::Session;

our $AUTOLOAD;

our %fields = (
	type    => undef,
	channel => undef,
	nick    => undef,
	ident   => undef,
	host    => undef,
	cmd     => undef,
	cmd_parameters => undef,
	msg     => undef,
	args    => undef,
	object  => undef,
	kernel  => undef,
	heap    => undef,
	state   => undef,
	sender  => undef,
	session => undef,
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

sub parse_parameters {
	my ($s, @args) = @_;	
	$s->args(@args[ARG0..$#_]);
	$s->object($args[OBJECT]);
	$s->session($args[SESSION]);
	$s->kernel($args[KERNEL]);
	$s->sender($args[SENDER]);
	$s->state($args[STATE]);
	$s->heap($args[HEAP]);
	return 0;
}

sub type {
	my ($s, $type) = @_;
	return $s->{type} unless $type;
	switch($type) {
		case IRCCMD_TYPE_PRV { $s->{type} = $type; }		
		case IRCCMD_TYPE_PUB { $s->{type} = $type; }				
		croak "Undefined IRC TYPE '$type'";
	};	
}

1;
