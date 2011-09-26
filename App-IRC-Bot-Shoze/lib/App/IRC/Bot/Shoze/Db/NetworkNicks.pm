package App::IRC::Bot::Shoze::Db::NetworkNicks;

use strict;
use warnings;

use Carp;

use IRC::Utils qw(:ALL);

use lib qw(../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Db::NetworkNicks::Object qw();
use App::IRC::Bot::Shoze::Log;

our $AUTOLOAD;

our %fields = (
    _handle => undef,
    _parent => undef,
);

# Constructor
#############
sub new {
    my ( $proto, $parent ) = @_;
    DEBUG( "Creating new " . __PACKAGE__, 8 );
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

sub list {
    my $s = shift;
    my $C = new App::IRC::Bot::Shoze::Db::NetworkNicks::Object( $s->_parent );
    return $C->_list();
}

sub get {
    my ( $s, $id ) = @_;
    DEBUG( __PACKAGE__ . "::get($id)", 3 );
    my $C = new App::IRC::Bot::Shoze::Db::NetworkNicks::Object( $s->_parent );
    return $C->_get($id);
}

sub get_by {
    my ( $s, $Network, $hash ) = @_;
    DEBUG( __PACKAGE__ . "::get_by($hash)", 3 );
    croak "Need Db::Networks::Object as first parameter"
      unless ref($Network) =~ /Db::Networks::Object/;
    $hash->{network_id} = $Network->id;
    my $C = new App::IRC::Bot::Shoze::Db::NetworkNicks::Object( $s->_parent );
    return $C->_get_by($hash);
}

sub create {
    my ( $s, $Network, $nick ) = @_;
    croak "Need Db::Networks::Object as first parameter"
      unless ref($Network) =~ /Db::Networks::Object/;
    my $A = new App::IRC::Bot::Shoze::Db::NetworkNicks::Object( $s->_parent );
    $A->network_id( $Network->id );
    $A->nick($nick);
#    $A->created_on(time);
    return $A->_create();
}

sub del {
    my ( $s, $Network, $Nick ) = @_;
    croak "Need Db::Networks::Object as first parameter"
      unless ref($Network) =~ /Db::Networks::Object/;
    croak "Need Db::NetworkNicks::Object as second parameter"
      unless ref($Nick) =~ /Db::NetworkNicks::Object/;
    my $db    = App::IRC::Bot::Shoze::Db->new;
    my $h     = $db->handle;
    my $query = <<SQL;
    DELETE FROM network_sessions WHERE network_id = ? AND nick_id = ? 
SQL
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute( $Network->id, $Nick->id )
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    $query = <<SQL;
    DELETE FROM network_channel_users WHERE nick_id = ?
SQL
    $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute( $Network->id, $Nick->id )
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    $query = <<SQL;
    DELETE FROM network_nicks WHERE nick_id = ?       
SQL
    $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute( $Nick->id )
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
}

sub empty {
    my ( $s, $Network ) = @_;
    croak "Need Db::Networks::Object as first parameter"
      unless ref($Network) =~ /Db::Networks::Object/;
    LOG("Clean ChannelUsers");
    my $db = App::IRC::Bot::Shoze::Db->new;
    $db->die_if_not_open();
    my $h = $db->handle;

    my $query = <<SQL;
    DELETE FROM network_sessions WHERE nick_id IN (SELECT id FROM network_nicks WHERE network_id = ?)
SQL

    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute( $Network->id )
      or die "Cannot execute query '$query' (" . $h->errstr . ")";

    $query = <<SQL;
    DELETE FROM network_channel_users WHERE nick_id IN (SELECT id FROM network_nicks WHERE network_id = ?)
SQL
    $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute( $Network->id )
      or die "Cannot execute query '$query' (" . $h->errstr . ")";

    $query = <<SQL;
    DELETE FROM network_nicks WHERE network_id = ?       
SQL
    $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute( $Network->id )
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    return $sth->rows;
}
1;
