package App::IRC::Bot::Shoze::Db::ChannelUsers;

use strict;
use warnings;

use Carp;

use IRC::Utils qw(:ALL);

use lib qw(../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Db::ChannelUsers::Object qw();
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
    DEBUG( "Creating new " . __PACKAGE__, 6);
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

sub get_by {
    my ( $s, $hash ) = @_;
    DEBUG( __PACKAGE__ . "::get_by($hash)", 4);
    my $C = new App::IRC::Bot::Shoze::Db::ChannelUsers::Object( $s->_parent );
    return $C->_get_by( $hash );
}

sub list {
    my ($s) = @_;
    LOG("List ChannelUsers");
    my $db = App::IRC::Bot::Shoze::Db->new;
    $db->die_if_not_open();
    my $h     = $db->handle;
    my $query = <<SQL;
        SELECT cu.lvl as lvl, cu.channel_id AS channel_id, cu.user_id AS user_id,
        nc.name AS channel_name, nc.type AS channel_type,
        u.name AS user_name, u.lvl AS user_lvl
        FROM channel_users AS cu, network_channels AS nc, users AS u
        WHERE cu.user_id = u.id AND cu.channel_id = nc.id;
SQL
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute()
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    my @list;

    while ( my $r = $sth->fetchrow_hashref ) {
        my $N = new App::IRC::Bot::Shoze::Db::ChannelUsers::Object($db);
        for my $k ( keys %{$N} ) {
            next if $k =~ /^_.*/;
            $N->$k( $r->{$k} );
        }
        my @extf = qw(channel_name channel_type user_name user_lvl);
        for (@extf) {
            $N->_add_permitted_field($_);
            $N->$_( $r->{$_} );
        }
        $N->synched;
        push @list, $N;
    }
    return @list;
}

1;
