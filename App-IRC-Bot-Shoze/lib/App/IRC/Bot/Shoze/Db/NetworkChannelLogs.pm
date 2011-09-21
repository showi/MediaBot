package App::IRC::Bot::Shoze::Db::NetworkChannelLogs;

use strict;
use warnings;

use Carp;

use IRC::Utils qw(:ALL);

use lib qw(../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Db::NetworkChannelLogs::Object qw();
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
sub list {
    my ( $s) = @_;
    my $db = App::IRC::Bot::Shoze::Db->new;
    $db->die_if_not_open();
    my $h     = $db->handle;
    my $query = <<SQL;
SELECT ncl.id AS id, ncl.type AS type, ncl.updated_on AS updated_on, ncl.created_on AS created_on,
ncl.active AS active, ncl.src_channel_id AS src_channel_id,
ncl.target_channel_id AS target_channel_id,
ncs.type AS src_network_channel_type, ncs.name AS src_network_channel_name,
nct.type AS target_network_channel_type, nct.name AS target_network_channel_name  
FROM network_channel_logs AS ncl,
network_channels AS ncs, network_channels AS nct, users AS u
WHERE ncl.src_channel_id = ncs.id 
AND ncl.target_channel_id = nct.id
AND ncl.user_id = u.id
SQL
    LOG( __PACKAGE__ . "::list $query" );
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute(  )
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    my @list;

    while ( my $r = $sth->fetchrow_hashref ) {
        my $N = new App::IRC::Bot::Shoze::Db::NetworkChannelLogs::Object($db);
        for my $k ( keys %{$N} ) {
            next if $k =~ /^_.*/;
            $N->$k( $r->{$k} );
        }
        my @extf =
          qw(src_network_channel_type src_network_channel_name target_network_channel_type target_network_channel_name);
        for (@extf) {
            $N->_add_permitted_field($_);
            $N->$_( $r->{$_} );
        }
        $N->synched;
        push @list, $N;
    }
    return @list;
}
sub list_by {
    my ( $s, $Network, $hash ) = @_;
    croak "Need Network object as first parameter "
      unless ref($Network) =~ /Db::Networks::Object/;
    my $db = App::IRC::Bot::Shoze::Db->new;
    $db->die_if_not_open();
    my $h     = $db->handle;
    my $query = <<SQL;
SELECT ncl.id AS id, ncl.type AS type, ncl.updated_on AS updated_on, ncl.created_on AS created_on,
ncl.active AS active, ncl.src_channel_id AS src_channel_id,
ncl.target_channel_id AS target_channel_id,
ncs.type AS src_network_channel_type, ncs.name AS src_network_channel_name,
nct.type AS target_network_channel_type, nct.name AS target_network_channel_name  
FROM network_channel_logs AS ncl, networks AS ns, networks AS nt, 
network_channels AS ncs, network_channels AS nct, users AS u
WHERE ncl.src_network_id = ns.id AND ncl.src_channel_id = ncs.id 
AND ncl.target_network_id = nt.id AND ncl.target_channel_id = nct.id
AND ncl.user_id = u.id AND ncl.src_network_id = ?
SQL
    my @args;
    push @args, $Network->id;
    for my $k(keys %{$hash}) {
        $query .= " AND $k = ?";
        push @args, $hash->{$k};
    }
    LOG( __PACKAGE__ . "::list $query" );
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute( @args)
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    my @list;

    while ( my $r = $sth->fetchrow_hashref ) {
        my $N = new App::IRC::Bot::Shoze::Db::NetworkChannelLogs::Object($db);
        for my $k ( keys %{$N} ) {
            next if $k =~ /^_.*/;
            $N->$k( $r->{$k} );
        }
        my @extf =
          qw(src_network_channel_type src_network_channel_name target_network_channel_type target_network_channel_name);
        for (@extf) {
            $N->_add_permitted_field($_);
            $N->$_( $r->{$_} );
        }
        $N->synched;
        push @list, $N;
    }
    return @list;
}

################################################################################
sub create {
    my ( $s, $ChanSrc, $type, $ChanTarget, $user_id) = @_;
    croak "Need Channel object as second parameter "
      unless ref($ChanSrc) =~ /Db::NetworkChannels::Object/;
    croak "Need Channel object as third parameter "
      unless ref($ChanTarget) =~ /Db::NetworkChannels::Object/;
    my $C =
      new App::IRC::Bot::Shoze::Db::NetworkChannelLogs::Object( $s->_parent );
    $C->user_id( $user_id );
    $C->type($type);
    $C->src_channel_id($ChanSrc->id);
    $C->target_channel_id($ChanTarget->id);
    $C->active(1);
    return $C->_create();
}

################################################################################
sub get_by {
    my ( $s, $hash ) = @_;

    my $C = new App::IRC::Bot::Shoze::Db::NetworkChannelLogs::Object( $s->_parent );
    return $C->_get_by($hash);

}


#
################################################################################
#sub clear_joined {
#    my ($s, $Network) = @_;
#    my $db =  App::IRC::Bot::Shoze::Db->new;
#    my $h     = $db->handle;
#    my $query = <<SQL;
#		UPDATE network_channels SET bot_joined = NULL WHERE network_id = ?;
#SQL
#    my $sth = $h->prepare($query)
#      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
#    $sth->execute($Network->id)
#      or die "Cannot execute query '$query' (" . $h->errstr . ")";
#    return $sth->rows;
#}
#

1;
