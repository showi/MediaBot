package MediaBot::Db::Networks;

use strict;
use warnings;

use Carp;

use lib qw(../../);
use MediaBot::Class qw(AUTOLOAD DESTROY LOG _get_root);
use MediaBot::Db::Networks::Object qw();

our $AUTOLOAD;

our %fields = (
	handle  => undef,
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

# Network exists?
##############
sub exists {
	my ( $s, $name ) = @_;
	$s->_parent->die_if_not_open();
	my $h     = $s->_parent->handle;
	my $query = <<SQL;
		SELECT * FROM networks WHERE name= ?
SQL
	my $sth = $h->prepare($query)
	  or die "Cannot prepare query '$query' (" . $h->errstr . ")";
	$sth->execute($name)
	  or die "Cannot execute query '$query' (" . $h->errstr . ")";
	my $row = $sth->fetch;
	return $row if $row;
	return 0;
}

# Create network
#############
sub create {
	my ( $s, $name, $description) = @_;
	$s->_parent->die_if_not_open();
	if ( $s->exists($name) ) {
		$s->LOG("DB::Error Network '$name' already exists");
		return 1;
	}
	my $h = $s->_parent->handle;
	my $query = <<SQL;
		INSERT INTO networks (name, description)
		VALUES (?, ?)
SQL
	my $sth = $h->prepare($query)
	  or die "Cannot prepare query '$query' (" . $h->errstr . ")";
	$sth->execute( $name, $description )
	  or die "Cannot execute query '$query' (" . $h->errstr . ")";
	return 0;
}

# Get network by name
#####################
sub get {
	my ( $s, $name ) = @_;
	$s->_parent->die_if_not_open();
	unless ( $s->exists($name) ) {
		$s->LOG("DB::Error Network '$name' doesn't exist");
		return undef;
	}
	my $h     = $s->_parent->handle;
	my $query = <<SQL;
		SELECT * FROM networks WHERE name= ?;
SQL
	my $sth = $h->prepare($query)
	  or die "Cannot prepare query '$query' (" . $h->errstr . ")";
	$sth->execute($name)
	  or die "Cannot execute query '$query' (" . $h->errstr . ")";
	my $rn = $sth->fetchrow_hashref;
	return undef unless $rn;
	my $N = new MediaBot::Db::Networks::Object();

	for my $k ( keys %{$N} ) {
		next if $k =~ /^_.*/;
		$N->$k( $rn->{$k} );
	}
	return $N;
}

# Delete network by name
########################
sub delete {
	my ( $s, $name) = @_;
	$s->_parent->die_if_not_open();
	unless ( $s->exists($name) ) {
		$s->LOG("DB::Error Cannot remove non existing network '$name'");
		return 1;
	}
	my $h     = $s->_parent->handle;
	my $query = <<SQL;
		DELETE FROM networks WHERE name= ? 
SQL
	my $sth = $h->prepare($query)
	  or die "Cannot prepare query '$query' (" . $h->errstr . ")";
	$sth->execute($name)
	  or die "Cannot execute query '$query' (" . $h->errstr . ")";
	return 0;
}

1;