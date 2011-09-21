package App::IRC::Bot::Shoze::Db::EasySentence::Object;

use strict;
use warnings;

use Carp;

use lib qw(../../../../../../);
use App::IRC::Bot::Shoze::Class qw(DESTROY);
use App::IRC::Bot::Shoze::Db::SynchObject qw(:ALL);
use App::IRC::Bot::Shoze::Log;

our $AUTOLOAD;

our %fields = (
    id         => undef,
    text       => undef,
    author     => undef,
    tags       => undef,
    updated_on => undef,
    created_on => undef,

    _object_name => undef,
    _object_db   => undef,
);

sub new {
    my ( $proto, $object_db, $object_name ) = @_;
    DEBUG( "Creating new " . __PACKAGE__ );
    print "ObjectDb: $object_db\n";
    croak "No database object passed as first parameter" unless ref($object_db);
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };

    bless( $s, $class );
    $s->_init_fields();    # DIRTY HACK VALUES IS SET TO 1 on init ...
    $s->_object_name($object_name);
    $s->_object_db($object_db);
    return $s;
}

1;
