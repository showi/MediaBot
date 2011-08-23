package MediaBot::Config;

use strict;
use warnings;

use Carp;

use YAML qw(LoadFile Dump);
use Data::Dumper qw(Dumper);

use lib qw(..);
use MediaBot::Class qw(AUTOLOAD DESTROY);

our $AUTOLOAD;

my %fields = (
	_parent => undef,
	_path   => 'cfg/',
	irc     => undef,
	db      => undef,
	bot		=> undef,
);

sub new {
	my ( $proto, $parent ) = @_;
	print "Creating new " . __PACKAGE__ . "\n";
	my $class = ref($proto) || $proto;
	my $s = {
		_permitted => \%fields,
		%fields,
	};
	bless( $s, $class );
	$s->_parent($parent);
	$s->read('irc');
	$s->read('db');
	$s->read('bot');
	return $s;
}

sub read {
	my ( $s, $name ) = @_;
	croak "No configuration name specified" unless $name;
	croak "Invalid configuration name '$name'"
	  if $name =~ /^_.*$/
		  or !grep( $name, keys %{ $s->{_permitted} } );

	my $f = $s->_parent->_path . $s->_path . "$name.yaml";
	croak "Configuration file not found '$f'"
	  unless -e $f;
	my $y = LoadFile($f);
	croak "Cannot load configuration file '$f' ($!)"
	  unless defined $y;
	$s->$name($y);

	#print Dumper $s->$name;
	return 0;
}

1;
