package App::IRC::Bot::Shoze::Db::Apero::Object;

use strict;
use warnings;

use Carp;

use lib qw(../../../);
use App::IRC::Bot::Shoze::Class qw(DESTROY);
use App::IRC::Bot::Shoze::Db::SynchObject qw(:ALL);
use App::IRC::Bot::Shoze::Log;

our $AUTOLOAD;

our %fields = (
    id      => undef,
    name    => undef,
    trigger => undef,
    text    => undef,
    chantext => undef,
    msg_type => undef,

    _object_name => undef,
    _object_db   => undef,
);

sub new {
    my ( $proto, $object_db ) = @_;
    DEBUG( "Creating new " . __PACKAGE__ , 5);
    croak "No database object passed as first parameter" unless ref($object_db);
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };

    bless( $s, $class );
    $s->_init_fields();    # DIRTY HACK VALUES IS SET TO 1 on init ...
    $s->_object_name('apero');
    $s->_object_db($object_db);
    return $s;
}

1;
