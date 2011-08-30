package MediaBot::Db;

use strict;
use warnings;

use Carp;
use DBI;

use lib qw(..);
use MediaBot::Class qw(AUTOLOAD DESTROY _get_root);
use MediaBot::Db::Users;
use MediaBot::Db::Networks;
use MediaBot::Db::Channels;
use MediaBot::Db::Sessions;
use MediaBot::Log;

our $AUTOLOAD;

our %fields = (
    handle   => undef,
    is_open  => undef,
    _parent  => undef,
    Users    => undef,
    Networks => undef,
    Sessions => undef,
    Channels => undef,
);

# Constructor
# Aggregate other Db modules so we have a kind of OO acces to SQL databases
sub new {
    my ( $proto, $parent ) = @_;
    DEBUG( "Creating new " . __PACKAGE__, 5);
    croak "No parent specified" unless ref $parent;
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    $s->_parent($parent);
    $s->Users( new MediaBot::Db::Users($s) );
    #$s->Networks( new MediaBot::Db::Networks($s) );
    $s->Sessions( new MediaBot::Db::Sessions($s) );
    $s->Channels( new MediaBot::Db::Channels($s) );
    $s->init();
    return $s;
}

# Opening database connection
sub init {
    my $s    = shift;
    my $c    = $s->_parent->Config->db;
    my $name = $c->{name};
    if ( $c->{driver} eq 'dbi:SQLite' ) {
        $name = $s->_parent->_path . $c->{name};
        croak "Invalid SQLite database: $name" unless ( -e $name );
    }
    $s->handle( DBI->connect( $c->{driver} . ":dbname=" . $name, "", "" ) );
    croak "DB connection failed (" . $c->{name} . ")" unless $s->handle;
    DEBUG("DB connection success ($c->{driver}:dbname=$name)");
    $s->is_open(1);
    return 0;
}

# Closing database connection
sub close {
    my ($s) = @_;
    $s->handle->disconnect if defined $s->handle;
    $s->handle(undef);
    $s->is_open(0);
}

# Try to reopen database handle or die, must find better way to handle failure for longtime running service.
sub die_if_not_open {
    my ($s) = @_;
    $s->init() unless $s->is_open();
}

1;

