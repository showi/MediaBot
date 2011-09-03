package MediaBot::Db::Channels::Object;

use strict;
use warnings;

use Carp;

use lib qw(../../../);
use MediaBot::Class qw(DESTROY);

#use MediaBot::Db::Class qw(AUTOLOAD synched is_synch);
use MediaBot::Db::SynchObject qw(:ALL);
use MediaBot::Log;

our $AUTOLOAD;

our %fields = (
    bot_mode       => undef,
    mode           => undef,
    bot_joined     => undef,
    password       => undef,
    auto_topic     => undef,
    ulimit         => undef,
    created_on     => undef,
    id             => undef,
    auto_op        => undef,
    owner          => undef,
    topic          => undef,
    auto_voice     => undef,
    name           => undef,
    active         => undef,
    auto_mode      => undef,
    type           => undef,
    created_by     => undef,
#    apikey         => undef,
#    apikey_private => undef,

    _object_name => undef,
    _object_db   => undef,
);

sub new {
    my ( $proto, $object_db ) = @_;
    DEBUG( "Creating new " . __PACKAGE__ );
    print "ObjectDb: $object_db\n";
    croak "No database object passed as first parameter" unless ref($object_db);
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    $s->_init_fields;    # DIRTY HACK
    $s->_object_name('channels');
    $s->_object_db($object_db);
    return $s;
}

sub _usable_name {
    my $s = shift;
    return $s->type . $s->name;

}
