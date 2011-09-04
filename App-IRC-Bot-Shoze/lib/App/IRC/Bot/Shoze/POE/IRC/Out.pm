package App::IRC::Bot::Shoze::POE::IRC::Out;

use strict;
use warnings;

use Carp;
use POE;
use POE::Component::IRC::Plugin qw(:ALL);

use lib qw(../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD);
use App::IRC::Bot::Shoze::Constants;
use App::IRC::Bot::Shoze::Log;

use Data::Dumper qw(Dumper);

our %fields = ( _parent => undef, Out => undef, );

sub new {
    my ($proto, $irc) = @_;
    croak "No irc object passed as first parameter"
        unless $irc;
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    $s->irc( $irc);
    return $s;
}


1;