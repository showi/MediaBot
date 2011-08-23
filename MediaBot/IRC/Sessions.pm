package MediaBot::IRC::Sessions;
use strict;
use warnings;

use Carp;
use Exporter;
use POE::Session;

use lib qw(../../);
use MediaBot::Class qw(AUTOLOAD DESTROY LOG _get_root);


our @ISA    = qw(Exporter);
our @EXPORT = qw();

our $AUTOLOAD;

our %fields = (
	_parent => undef,
);

# Constructor
#############
sub new {
	my ( $proto, $parent ) = @_;
	print "Creating new " . __PACKAGE__ . "\n";
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

sub add {
	my ($s, $nick, $ident, $host) = @_;
	print "Session add: $nick $ident@"."$host\n";
	
	
}


1;
