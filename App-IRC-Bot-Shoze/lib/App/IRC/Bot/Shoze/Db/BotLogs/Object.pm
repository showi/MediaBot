package App::IRC::Bot::Shoze::Db::BotLogs::Object;

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
    type       => undef,
    src        => undef,
    target     => undef,
    msg        => undef,
    created_on => undef,
    network_id => undef,

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

    # DIRTY HACK VALUES IS SET TO 1 on init ...
    $s->_init_fields();
    $s->_object_name('bot_logs');
    $s->_object_db($object_db);
    return $s;
}

1;
