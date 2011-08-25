package MediaBot;
use strict;
use warnings;

use MediaBot::Class qw(AUTOLOAD DESTROY _get_root);
use MediaBot::Config;
use MediaBot::IRC;
use MediaBot::Db;
use MediaBot::Log;

our $PROGRAMNAME  = "ShowBoat";
our $VERSION      = "0.0.1a";
our $PROGRAMBIRTH = "1313893570";
our $DEBUG        = 1;

our %fields = (
    _path  => "",
    _debug => 1,
    Config => undef,
    Irc    => undef,
    Db     => undef,
    Log    => undef,
);

sub new {
    my ( $proto, $path ) = @_;
    MediaBot::Log::flush();
    DEBUG( "Creating new " . __PACKAGE__ );
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    $s->_path($path) if $path;
    $s->read_config($s);
    $s->Irc( new MediaBot::IRC($s) );
    $s->Db( new MediaBot::Db($s) );
    return $s;
}

sub read_config {
    my $s = shift;
    $s->Config( new MediaBot::Config($s) );
}

1;
