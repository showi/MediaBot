package App::IRC::Bot::Shoze::Db::Sessions;

use strict;
use warnings;

use Carp;

use lib qw(../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Db::Sessions::Object;
use App::IRC::Bot::Shoze::Log;

our $AUTOLOAD;

our %fields = (
    handle  => undef,
    _parent => undef,
);

# Constructor
#############
sub new {
    my ( $proto, $parent ) = @_;
    DEBUG( "Creating new " . __PACKAGE__, 5);
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
    my ( $s, $user, $hostname ) = @_;
    $s->_parent->die_if_not_open();
    my $h     = $s->_parent->handle;
    my $query = <<SQL;
		SELECT * FROM sessions WHERE user = ? AND hostname = ?
SQL
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute( $user, $hostname )
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    my $row = $sth->fetch;
    return $row if $row;
    return 0;
}

# Create session
#############
sub create {
    my ( $s, $nick, $user, $hostname ) = @_;
    $s->_parent->die_if_not_open();
    if ( $s->exists( $user, $hostname ) ) {
        $s->LOG("DB::Error Sessions '$nick $user @ $hostname'  already exists");
        return 1;
    }
    my $h     = $s->_parent->handle;
    my $time  = time;
    my $query = <<SQL;
		INSERT INTO sessions (nick, user, hostname, first_access, last_access, flood_start, flood_end, flood_numcmd, ignore)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
SQL
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute( $nick, $user, $hostname, $time, $time, $time, $time + 60, 1, undef )
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    return 0;
}

sub update {
    my ( $s, $Session ) = @_;
    my $h    = $s->_parent->handle;
    my $time = time;
    if ( $Session->ignore ) {
        if ( $Session->ignore < $time ) {
            $Session->ignore(undef);
        }
        else {
            #print "Ignored user!\n";
            return 0;
        }
    }
    if ( $Session->flood_end < $time ) {
        #print "Reseting flood!\n";
        $Session->flood_start($time);
        $Session->flood_end( $time + 60 );
        $Session->flood_numcmd(0);
    }
    else {
        if ( $Session->flood_numcmd > 10  ) {
            #print "Flood detected ignore user 5mn!\n";
            $Session->ignore( $time + 30 );
        }
        else {
            $Session->flood_numcmd( $Session->flood_numcmd + 1 );
        }
    }
    my $query = <<SQL;
    UPDATE sessions SET nick = ?, flood_start = ?, flood_end = ?,
    flood_numcmd = ?, ignore = ?, last_access = ?, user_id = ?
    WHERE id = ?
SQL
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute($Session->nick,
        $Session->flood_start, $Session->flood_end, $Session->flood_numcmd,
        $Session->ignore, $time, $Session->user_id, $Session->id
    ) or die "Cannot execute query '$query' (" . $h->errstr . ")";
    return 0 if $Session->ignore;
    return 1;
}

sub delete_idle {
    my ($s)    = @_;
    my $tlimit = time - 600;
    my $h      = $s->_parent->handle;
    my $query  = <<SQL;
	   DELETE FROM sessions 
	   WHERE first_access < ? AND ignore IS NULL AND user_id IS NULL 
SQL
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute($tlimit)
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    return 0;

}

# Get session by name
#####################
sub get {
    my ( $s, $nick, $user, $hostname ) = @_;
    $s->_parent->die_if_not_open();
    unless ( $s->exists( $user, $hostname ) ) {
        $s->LOG("DB::Error Network '$user @ $hostname' doesn't exist");
        return undef;
    }
    my $h     = $s->_parent->handle;
    my $query = <<SQL;
		SELECT * FROM sessions WHERE nick = ? AND user = ? AND hostname = ?;
SQL
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute( $nick, $user, $hostname )
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    my $rn = $sth->fetchrow_hashref;
    return undef unless $rn;

    my $N = new App::IRC::Bot::Shoze::Db::Sessions::Object();
    for my $k ( keys %{$N} ) {
        next if $k =~ /^_.*/;
        $N->$k( $rn->{$k} );
    }
    return $N;
}

# Get session by name
#####################
sub get_by_user_hostname {
    my ( $s, $user, $hostname ) = @_;
    $s->_parent->die_if_not_open();
    unless ( $s->exists( $user, $hostname ) ) {
        $s->LOG("DB::Error Network '$user @ $hostname' doesn't exist");
        return undef;
    }
    my $h     = $s->_parent->handle;
    my $query = <<SQL;
		SELECT * FROM sessions WHERE user = ? AND hostname = ?;
SQL
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute( $user, $hostname )
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    my $rn = $sth->fetchrow_hashref;
    return undef unless $rn;

    my $N = new App::IRC::Bot::Shoze::Db::Sessions::Object();
    for my $k ( keys %{$N} ) {
        next if $k =~ /^_.*/;
        $N->$k( $rn->{$k} );
    }
    return $N;
}

# Delete network by name
########################
sub delete {
    my ( $s, $id) = @_;
    $s->_parent->die_if_not_open();
    my $h     = $s->_parent->handle;
    my $query = <<SQL;
		DELETE FROM sessions WHERE id = ?
SQL
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute(  $id )
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    return $sth->rows;
}

1;
