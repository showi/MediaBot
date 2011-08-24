package MediaBot::IRC::Commands::Plugins::Version;

use strict;
use warnings;

use Carp;

use lib qw(../../../../);
use MediaBot::Class qw(AUTOLOAD DESTROY LOG);

our $AUTOLOAD;

our %fields = (
    _parent => undef,
    cmd => undef,
);

# Constructor
#############
sub new {
	my ( $proto, $parent) = @_;
    print "Creating new " . __PACKAGE__ . "\n";
    croak "No parent specified" unless ref $parent;
	my $class = ref($proto) || $proto;
	my $s = {
		_permitted => \%fields,
		%fields,
	};
	bless( $s, $class );
	$s->_parent($parent);
    $s->cmd('version');
	return $s;
}

sub run {
    my ($s, $CO) = @_;
    print "Running plugin " . __PACKAGE__ . ": " . $CO->cmd. "\n";
}
1;