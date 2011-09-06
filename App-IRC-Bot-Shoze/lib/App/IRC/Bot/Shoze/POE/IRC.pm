package App::IRC::Bot::Shoze::POE::IRC;

use strict;
use warnings;

use Carp;
use POE;
use POE::Component::IRC::Plugin qw(:ALL);

use lib qw(../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD _get_root);
use App::IRC::Bot::Shoze::Constants;
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::POE::IRC::Out;

use Data::Dumper qw(Dumper);

our %fields = ( 
    _parent => undef, 
    Out => undef, 
    session_id => undef,
    poco => undef,
);

sub new {
    my ($proto, $parent) = @_;
    croak "No parent object passed as first parameter"
        unless ref($parent);
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    $s->_parent($parent);
    $s->Out( new App::IRC::Bot::Shoze::POE::IRC::Out($s));
    return $s;
}


1;