package App::IRC::Bot::Shoze::Db;

use strict;
use warnings;

use Carp;
use DBI;

use lib qw(../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::Db::Users;
use App::IRC::Bot::Shoze::Db::Networks;
use App::IRC::Bot::Shoze::Db::Channels;
use App::IRC::Bot::Shoze::Db::Sessions;
use App::IRC::Bot::Shoze::Db::Apero;
use App::IRC::Bot::Shoze::Db::EasySentence;


our $AUTOLOAD;

our %fields = (
    handle  => undef,
    is_open => undef,
    _parent => undef,
    Users   => undef,

    #Networks => undef,
    Sessions  => undef,
    Channels  => undef,
    Apero     => undef,
    Sentences => undef,
);

# Constructor
# Aggregate other Db modules so we have a kind of OO acces to SQL databases
sub new {
    my ( $proto, $parent ) = @_;
    DEBUG( "Creating new " . __PACKAGE__, 5 );
    croak "No parent specified" unless ref $parent;
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    $s->_parent($parent);
    $s->Users( new App::IRC::Bot::Shoze::Db::Users($s) );

    #$s->Networks( new MediaBot::Db::Networks($s) );
    $s->Sessions( new App::IRC::Bot::Shoze::Db::Sessions($s) );
    $s->Channels( new App::IRC::Bot::Shoze::Db::Channels($s) );
    $s->Apero( new App::IRC::Bot::Shoze::Db::Apero($s) );
    $s->Sentences( new App::IRC::Bot::Shoze::Db::EasySentence($s) );
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

