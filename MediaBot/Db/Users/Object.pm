package MediaBot::Db::Users::Object;

use strict;
use warnings;

use Carp;

use lib qw(../../../);
use MediaBot::Class qw(DESTROY);
use MediaBot::Db::SynchObject qw(:ALL);
use MediaBot::Log;

our $AUTOLOAD;

our %fields = (
    id            => undef,
    apikey  => undef,
    apikey_private => undef,
    hostmask => undef,
    pending => undef,
    lvl => undef,
    name => undef,
    password => undef,
    is_bot => undef,
    
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
    $s->_init_fields(); # DIRTY HACK VALUES IS SET TO 1 on init ...
    $s->_object_name('users');
    $s->_object_db($object_db);
            for my $k (keys %{$s->{_permitted}}) {
       print "KEY : $k => " . $s->{$k} . "\n";
    }
    return $s;
}

sub _usable_name {
    my $s = shift;
    return $s->type . $s->name;
    
} 