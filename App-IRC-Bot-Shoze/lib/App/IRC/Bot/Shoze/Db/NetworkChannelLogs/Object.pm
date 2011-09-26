package App::IRC::Bot::Shoze::Db::NetworkChannelLogs::Object;

use strict;
use warnings;

use Carp;

use lib qw(../../../../../../);
use App::IRC::Bot::Shoze::Class qw(DESTROY);
use App::IRC::Bot::Shoze::Db::SynchObject qw(:ALL);
use App::IRC::Bot::Shoze::Log;

our $AUTOLOAD;

our %fields = (
    id                => undef,
    active            => undef,
    created_on        => undef,
    updated_on        => undef,
    user_id           => undef,
    src_channel_id    => undef,
    src_network_id    => undef,
    target_channel_id => undef,
    target_network_id => undef,
    type              => undef,

    _object_name => undef,
    _object_db   => undef,
);

sub new {
    my ( $proto, $object_db ) = @_;
    DEBUG( "Creating new " . __PACKAGE__, 8 );
    croak "No database object passed as first parameter"
      unless ref($object_db);
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    $s->_init_fields;            # DIRTY HACK
    $s->_object_name('network_channel_logs');
    $s->_object_db($object_db);
    return $s;
}

