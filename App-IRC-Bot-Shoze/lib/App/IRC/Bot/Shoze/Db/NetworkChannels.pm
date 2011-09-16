package App::IRC::Bot::Shoze::Db::NetworkChannels;

use strict;
use warnings;

use Carp;

use IRC::Utils qw(:ALL);

use lib qw(../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Db::NetworkChannels::Object qw();
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

###############################################################################
sub list {
    my ($s, $Network) = @_;
    croak "Need Network object as first parameter " 
        unless ref($Network) =~ /Db::Networks::Object/;
    my $db =  App::IRC::Bot::Shoze::Db->new;
    $db->die_if_not_open();
    my $h     = $db->handle;
    my $query = <<SQL;
SELECT c.bot_mode AS bot_mode, c.mode AS mode, c.bot_joined AS bot_joined,
		c.password AS password, c.auto_topic AS auto_topic, c.ulimit AS ulimit, 
		c.created_on AS created_on, c.id AS id, c.auto_op AS auto_op, c.owner AS owner,
		c.topic AS topic, c.auto_voice AS auto_voice, c.name AS name, c.active AS active,
		c.auto_mode AS auto_mode, c.type AS type, c.created_by AS created_by, 
		c.topic_setby AS topic_setby, c.topic_seton AS topic_seton,
		u.name AS user_name, u.lvl AS user_lvl, u.is_bot AS user_is_bot
		FROM network_channels AS c, networks AS n
		LEFT JOIN Users AS u ON u.id = c.owner
		WHERE n.id = ? AND c.network_id = n.id  
SQL
    LOG(__PACKAGE__ . "::list $query");
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute($Network->id)
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    my @list;
    while ( my $r = $sth->fetchrow_hashref ) {
        my $N = new App::IRC::Bot::Shoze::Db::NetworkChannels::Object($db);
        for my $k ( keys %{$N} ) {
            next if $k =~ /^_.*/;
            $N->$k( $r->{$k} );
        }
        if (defined $r->{user_name}) {
            my @extf = qw(user_name user_lvl user_is_bot);
            for(@extf) {
                $N->_add_permitted_field($_);
                $N->$_($r->{$_});
            }
        }
        print "Chan:" . $N->_usable_name . "\n";
        $N->synched;
        push @list, $N;
    }
    return @list;
}

###############################################################################
sub get_by {
    my ( $s, $Network, $type, $name ) = @_;
        croak "Need Network object as first parameter " 
        unless ref($Network) =~ /Db::Networks::Object/;
    $type->{network_id} = $Network->id;
    my $C = new App::IRC::Bot::Shoze::Db::NetworkChannels::Object( $s->_parent );
    return $C->_get_by($type);

}

###############################################################################
sub create {
    my ( $s, $Network, $type, $name, $owner ) = @_;
    croak "Need Network object as first parameter " 
        unless ref($Network) =~ /Db::Networks::Object/;
    my $C = new App::IRC::Bot::Shoze::Db::NetworkChannels::Object( $s->_parent );
    $C->network_id($Network->id);
    $C->type($type);
    $C->name($name);
    $C->owner($owner);
    $C->created_by($owner);
    $C->active(1);
    return $C->_create();
}

###############################################################################
sub clear_joined {
    my ($s, $Network) = @_;
    my $db =  App::IRC::Bot::Shoze::Db->new;
    my $h     = $db->handle;
    my $query = <<SQL;
		UPDATE network_channels SET bot_joined = NULL WHERE network_id = ?;
SQL
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute($Network->id)
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    return $sth->rows;
}

1;
