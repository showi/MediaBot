package App::IRC::Bot::Shoze::HTTP::rest::db::user;

use strict;
use warnings;

use Carp;

use HTTP::Response;
use YAML qw'freeze thaw Bless';

use lib qw(../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Log;
our $AUTOLOAD;

our %fields = (
    _parent  => undef,
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
    return $s;
}

1;