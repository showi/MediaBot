package App::IRC::Bot::Shoze::Db::NetworkSessions;

use strict;
use warnings;

use Carp;

use lib qw(../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Db::NetworkSessions::Object qw();
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
    DEBUG( "Creating new " . __PACKAGE__, 6 );
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

###############################################################################
sub create {
    my ( $s, $Nick, $user, $hostname ) = @_;
    croak "Need Nick object as first parameter"
      unless ref($Nick) =~ /Db::NetworkNicks::Object/;
    my $time = time;
    my $O =
      new App::IRC::Bot::Shoze::Db::NetworkSessions::Object( $s->_parent );
    $O->nick_id( $Nick->id );
    $O->user($user);
    $O->hostname($hostname);
    $O->first_access($time);
    $O->last_access($time);
    $O->flood_start($time);
    $O->flood_end( $time + 60 );
    $O->flood_numcmd(1);
    $O->ignore(undef);
    return $O->_create();
}

###############################################################################
sub update {
    my ( $s, $Session ) = @_;
    croak "Need Nick object as first parameter"
      unless ref($Session) =~ /Db::NetworkSessions::Object/;
    my $h    = $s->_parent->handle;
    my $time = time;
    if ( $Session->ignore ) {
        if ( $Session->ignore < $time ) {
            $Session->ignore(undef);
        }
        else {
            return 0;
        }
    }
    if ( $Session->flood_end < $time ) {
        $Session->flood_start($time);
        $Session->flood_end( $time + 60 );
        $Session->flood_numcmd(0);
    }
    else {
        if ( $Session->flood_numcmd > 10 ) {
            $Session->ignore( $time + 30 );
        }
        else {
            $Session->flood_numcmd( $Session->flood_numcmd + 1 );
        }
    }
    return $Session->_update();
}

###############################################################################
sub delete_idle {
    my ($s)    = @_;
    my $tlimit = time - 600;
    my $h      = $s->_parent->handle;
    my $query  = <<SQL;
	   DELETE FROM network_sessions 
	   WHERE first_access < ? AND ignore IS NULL AND user_id IS NULL 
SQL
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute($tlimit)
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    return 0;

}

###############################################################################
sub get_by {
    my ( $s, $Nick, $hash ) = @_;
    croak "Need Nick object as first parameter"
      unless ref($Nick) =~ /Db::NetworkNicks::Object/;
    $hash->{nick_id} = $Nick->id;
    my $N =
      new App::IRC::Bot::Shoze::Db::NetworkSessions::Object( $s->_parent );
    return $N->_get_by($hash);
}

1;
