package App::IRC::Bot::Shoze::Db;

use strict;
use warnings;

use Carp;
use DBI;

use lib qw(../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::Config;
use App::IRC::Bot::Shoze::Db::Users;

use App::IRC::Bot::Shoze::Db::Networks;
use App::IRC::Bot::Shoze::Db::NetworkNicks;
use App::IRC::Bot::Shoze::Db::NetworkChannels;
use App::IRC::Bot::Shoze::Db::NetworkChannelUsers;
use App::IRC::Bot::Shoze::Db::NetworkSessions;

use App::IRC::Bot::Shoze::Db::ChannelUsers;
use App::IRC::Bot::Shoze::Db::Apero;
use App::IRC::Bot::Shoze::Db::EasySentence;
use App::IRC::Bot::Shoze::Db::ChannelAutoMode;

our $AUTOLOAD;

our $Singleton = undef;

our %fields = (
    handle  => undef,
    is_open => undef,

    Networks            => undef,
    NetworkNicks        => undef,
    NetworkSessions     => undef,
    NetworkChannels     => undef,
    NetworkChannelUsers => undef,
    
    Users           => undef,
    ChannelUsers    => undef,
    Apero           => undef,
    Sentences       => undef,
    ChannelAutoMode => undef,
);

# Constructor
# Aggregate other Db modules so we have a kind of OO acces to SQL databases
sub new {
    my ($proto) = @_;
    if ($Singleton) {
        return $Singleton;
    }

    DEBUG( "Creating new " . __PACKAGE__, 6 );
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    $s->Networks( new App::IRC::Bot::Shoze::Db::Networks($s) );
    $s->NetworkNicks( new App::IRC::Bot::Shoze::Db::NetworkNicks($s) );
    $s->NetworkSessions( new App::IRC::Bot::Shoze::Db::NetworkSessions($s) );
    $s->Users( new App::IRC::Bot::Shoze::Db::Users($s) );
    $s->NetworkChannels( new App::IRC::Bot::Shoze::Db::NetworkChannels($s) );
    $s->ChannelUsers( new App::IRC::Bot::Shoze::Db::ChannelUsers($s) );
    $s->Apero( new App::IRC::Bot::Shoze::Db::Apero($s) );
    $s->Sentences( new App::IRC::Bot::Shoze::Db::EasySentence($s) );
    $s->ChannelAutoMode( new App::IRC::Bot::Shoze::Db::ChannelAutoMode($s) );
    $s->NetworkChannelUsers(
        new App::IRC::Bot::Shoze::Db::NetworkChannelUsers($s) );
    $s->init();
    $Singleton = $s;
    return $Singleton;
}

# Opening database connection
sub init {
    my $s = shift;
    my $c = App::IRC::Bot::Shoze::Config->new;

    # my $Shoze = App::IRC::Bot::Shoze->new;
    my $name = $c->{name};
    if ( $c->db->{driver} eq 'dbi:SQLite' ) {
        $name = $c->_base_path . $c->db->{name};
        croak "Invalid SQLite database: $name" unless ( -e $name );
    }
    $s->handle( DBI->connect( $c->db->{driver} . ":dbname=" . $name, "", "" ) );
    croak "DB connection failed (" . $c->db->{name} . ")" unless $s->handle;
    LOG("--- Database ---");
    LOG( "DB connection success (" . $c->db->{driver} . ":dbname=$name)" );
    LOG("--- Database ---");
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

# Try to reopen database handle or die, must find better way to handle
# failure for longtime running service.
sub die_if_not_open {
    my ($s) = @_;
    $s->init() unless $s->is_open();
}

1;

