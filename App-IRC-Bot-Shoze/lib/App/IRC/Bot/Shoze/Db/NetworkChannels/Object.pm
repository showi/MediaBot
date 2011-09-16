package App::IRC::Bot::Shoze::Db::NetworkChannels::Object;

use strict;
use warnings;

use Carp;

use lib qw(../../../../../../);
use App::IRC::Bot::Shoze::Class qw(DESTROY);
use App::IRC::Bot::Shoze::Db::SynchObject qw(:ALL);
use App::IRC::Bot::Shoze::Log;

our $AUTOLOAD;

our %fields = (
    bot_mode    => undef,
    mode        => undef,
    bot_joined  => undef,
    password    => undef,
    auto_topic  => undef,
    ulimit      => undef,
    created_on  => undef,
    id          => undef,
    auto_op     => undef,
    owner       => undef,
    topic       => undef,
    topic_setby => undef,
    topic_seton => undef,
    auto_voice  => undef,
    name        => undef,
    active      => undef,
    auto_mode   => undef,
    type        => undef,
    created_by  => undef,
    network_id  => undef,
    
    _object_name => undef,
    _object_db   => undef,
);

sub new {
    my ( $proto, $object_db ) = @_;
    DEBUG( "Creating new " . __PACKAGE__, 5);
    croak "No database object passed as first parameter" unless ref($object_db);
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    $s->_init_fields;    # DIRTY HACK
    $s->_object_name('network_channels');
    $s->_object_db($object_db);
    return $s;
}

sub _usable_name {
    my $s = shift;
    return $s->type . $s->name;

}
