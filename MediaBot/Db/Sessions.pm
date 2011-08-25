package MediaBot::Db::Sessions;

use strict;
use warnings;

use Carp;

use lib qw(../../);
use MediaBot::Class qw(AUTOLOAD DESTROY _get_root);
use MediaBot::Db::Sessions::Object;
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
    DEBUG("Creating new " . __PACKAGE__);
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

# Sessions exists?
##############
sub exists {
    my ( $s, $nick, $ident, $host ) = @_;
    $s->_parent->die_if_not_open();
    my $h     = $s->_parent->handle;
    my $query = <<SQL;
		SELECT * FROM sessions WHERE nick = ? AND ident = ? AND host = ?
SQL
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute( $nick, $ident, $host )
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    my $row = $sth->fetch;
    return $row if $row;
    return 0;
}

# Create session
#############
sub create {
    my ( $s, $nick, $ident, $host ) = @_;
    $s->_parent->die_if_not_open();
    if ( $s->exists( $nick, $ident, $host ) ) {
        $s->LOG("DB::Error Sessions '$nick $ident @ $host'  already exists");
        return 1;
    }
    my $h     = $s->_parent->handle;
    my $time  = time;
    my $query = <<SQL;
		INSERT INTO sessions (nick, ident, host, first_request, flood_start, flood_end, flood_numcmd, ignore)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?)
SQL
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute( $nick, $ident, $host, $time, $time, $time + 60,
        1, 0)
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    return 0;
}

sub update_newrequest {
    my ( $s, $Session ) = @_;
    my $h     = $s->_parent->handle;
    my $time = time;
    if ($Session->ignore) {
        if ($Session->ignore < $time) {
            $Session->ignore(undef);
        } else {
            print "Ignored user!\n";
            return 0;
        }
    }
    if ($Session->flood_end < $time) {
        print "Reseting flood!\n";
        $Session->flood_start($time);
        $Session->flood_end($time + 60);
        $Session->flood_numcmd(0);
    } else {
        if ($Session->flood_numcmd > 5 ) {
            print "Flood detected ignore user 5mn!\n";
            $Session->ignore($time + 300);
        } else {
            $Session->flood_numcmd($Session->flood_numcmd + 1);
        }
    }
    my $query = <<SQL;
    UPDATE sessions SET flood_start = ?, flood_end = ?,
    flood_numcmd = ?, ignore = ? 
    WHERE id = ?
SQL
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute( $Session->flood_start, $Session->flood_end, 
    $Session->flood_numcmd, $Session->ignore, $Session->id)
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    return 0 if $Session->ignore;
    return 1;
}

sub delete_idle {
    my ($s)    = @_;
    my $tlimit = time - 600;
    my $h      = $s->_parent->handle;
    my $query  = <<SQL;
	   DELETE FROM sessions WHERE first_request < ? AND ignore IS NULL
SQL
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute($tlimit)
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    return 0;

}

# Get network by name
#####################
sub get {
    my ( $s, $nick, $ident, $host ) = @_;
    $s->_parent->die_if_not_open();
    unless ( $s->exists( $nick, $ident, $host ) ) {
        $s->LOG("DB::Error Network '$nick' doesn't exist");
        return undef;
    }
    my $h     = $s->_parent->handle;
    my $query = <<SQL;
		SELECT * FROM sessions WHERE nick = ? AND ident = ? AND host = ?;
SQL
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute( $nick, $ident, $host )
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    my $rn = $sth->fetchrow_hashref;
    return undef unless $rn;

    my $N = new MediaBot::Db::Sessions::Object();

    for my $k ( keys %{$N} ) {
        next if $k =~ /^_.*/;
        $N->$k( $rn->{$k} );
    }
    return $N;
}

# Delete network by name
########################
sub delete {
    my ( $s, $nick, $ident, $host ) = @_;
    $s->_parent->die_if_not_open();
    unless ( $s->exists( $nick, $ident, $host ) ) {
        $s->LOG("DB::Error Cannot remove non existing network '$nick'");
        return 1;
    }
    my $h     = $s->_parent->handle;
    my $query = <<SQL;
		DELETE FROM sessions WHERE nick = ? AND ident = ? AND host = ? 
SQL
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute( $nick, $ident, $host )
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    return 0;
}

1;
