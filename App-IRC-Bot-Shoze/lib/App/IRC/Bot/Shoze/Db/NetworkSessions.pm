package App::IRC::Bot::Shoze::Db::NetworkSessions;

use strict;
use warnings;

use Carp;

use lib qw(../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Db::NetworkSessions::Object qw();
use App::IRC::Bot::Shoze::Log;

use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Helper qw(_get_nick);
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
    croak "Need Session object as first parameter"
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
    my $h      = App::IRC::Bot::Shoze::Db->new->handle;
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
# Get session with extend informations from user table if user's logged
###############################################################################
sub get_extended {
    my ( $s, $Network, $nick, $user, $hostname ) = @_;
    my $db = App::IRC::Bot::Shoze::Db->new;
    my $Nick = $s->_get_nick( $db, $Network, $nick );
    unless ($Nick) {
        WARN( "Cannot get nick '$nick' for network " . $Network->name );
        return undef;
    }
    my $h     = $db->handle;
    my $query = <<SQL;
    SELECT ns.last_access AS last_access, ns.ignore AS ignore, 
    ns.flood_numcmd AS flood_numcmd, ns.flood_end AS flood_end, 
    ns.flood_start AS flood_start, ns.user AS user, ns.hostname AS hostname,
    ns.id AS id, ns.first_access AS first_access, ns.nick_id AS nick_id, 
    ns.user_id AS user_id, nn.nick AS nick, u.name AS user_name, u.lvl AS user_lvl,
    u.pending AS user_pending, u.hostmask AS user_hostmask, u.password AS user_password,
    u.is_bot AS user_is_bot, u.created_on AS user_created_on
    FROM network_sessions AS ns, network_nicks AS nn
    LEFT JOIN users AS u ON ns.user_id = u.id
    WHERE ns.nick_id = nn.id AND nn.nick = ? AND ns.user = ? AND ns.hostname = ?
SQL
    LOG( __PACKAGE__ . "::get_extended: " . $query, 5 );
    LOG( __PACKAGE__ . " params: $nick, $user, $hostname" );
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute( $nick, $user, $hostname )
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    LOG( "Rows: " . $sth->rows );

    #return undef if  $sth->rows < 1;
    LOG( __PACKAGE__ . " got result" );
    my $r = $sth->fetchrow_hashref;
    my $S = new App::IRC::Bot::Shoze::Db::NetworkSessions::Object($db);
    for my $k ( keys %{$S} ) {
        next if $k =~ /^_.*/;
        $S->$k( $r->{$k} );
    }
    my @extf = qw(
      nick user_name user_lvl user_pending user_hostmask user_password user_is_bot user_created_on
    );
    for (@extf) {
        $S->_add_permitted_field($_);
        $S->$_( $r->{$_} );
    }
    $S->synched;
    return $S;

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
