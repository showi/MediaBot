package MediaBot::Db::Channels;

use strict;
use warnings;

use Carp;

use lib qw(../../);
use MediaBot::Class qw(AUTOLOAD DESTROY _get_root);
use MediaBot::Db::Channels::Object qw();
use MediaBot::Log;

our $AUTOLOAD;

our %fields = (
    handle  => undef,
    _parent => undef,
);

# Constructor
#############
sub new {
    my ( $proto, $parent ) = @_;
    DEBUG( "Creating new " . __PACKAGE__ );
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

# Channels exists?
##############
sub exists {
    my ( $s, $type, $name ) = @_;
    $s->_parent->die_if_not_open();
    my $h     = $s->_parent->handle;
    my $query = <<SQL;
		SELECT * FROM channels WHERE type =? AND name= ?
SQL
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute( $type, $name )
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    my $row = $sth->fetch;
    return $row if $row;
    return 0;
}

# Create channel
#############
sub create {
    my ( $s, $type, $name, $user_id ) = @_;
    $s->_parent->die_if_not_open();
    if ( $s->exists( $type, $name ) ) {
        $s->LOG("DB::Error Network '$name' already exists");
        return 1;
    }
    my $h     = $s->_parent->handle;
    my $query = <<SQL;
		INSERT INTO channels (type, name, active, created_by, created_on)
		VALUES (?, ?, ?, ?, ?)
SQL
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute( $type, $name, 1, $user_id, time )
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    return $sth->rows;
}

# Create channel
#############
sub set {
    my ( $s, $id, $field, $value ) = @_;
    $s->_parent->die_if_not_open();
    my $h     = $s->_parent->handle;
    my $query = <<SQL;
        UPDATE channels SET $field = ? WHERE id = ?; 
SQL
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute( $value, $id)
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    return $sth->rows;
}

# Get channel by name
#####################
sub get {
    my ( $s, $type, $name ) = @_;
    $s->_parent->die_if_not_open();
    unless ( $s->exists( $type, $name ) ) {
        $s->LOG("DB::Error Channel '$type$name' doesn't exist");
        return undef;
    }
    my $h     = $s->_parent->handle;
    my $query = <<SQL;
		SELECT * FROM channels WHERE type = ? AND name= ?;
SQL
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute( $type, $name )
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    my $rn = $sth->fetchrow_hashref;
    return undef unless $rn;
    my $N = new MediaBot::Db::Channels::Object();

    for my $k ( keys %{$N} ) {
        next if $k =~ /^_.*/;
        $N->$k( $rn->{$k} );
    }
    return $N;
}

# Get channel by name
#####################
sub list {
    my ($s) = @_;
    $s->_parent->die_if_not_open();
    my $h     = $s->_parent->handle;
    my $query = <<SQL;
		SELECT * FROM channels;
SQL
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute()
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    my @list;
    while ( my $r = $sth->fetchrow_hashref ) {
        my $N = new MediaBot::Db::Channels::Object();
        for my $k ( keys %{$N} ) {
            next if $k =~ /^_.*/;
            $N->$k( $r->{$k} );
        }
        push @list, $N;
    }
    return @list;
}

# Delete channel by name
########################
sub delete {
    my ( $s, $name ) = @_;
    $s->_parent->die_if_not_open();
    unless ( $s->exists($name) ) {
        $s->LOG("DB::Error Cannot remove non existing channel '$name'");
        return 1;
    }
    my $h     = $s->_parent->handle;
    my $query = <<SQL;
		DELETE FROM channels WHERE name= ? 
SQL
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute($name)
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    return 0;
}

1;
