package App::IRC::Bot::Shoze::POE;

use warnings;
use strict;

use Carp;

use POE qw(
  Component
  Component::IRC
  Component::IRC::Plugin::AutoJoin
  Component::IRC::Plugin::CycleEmpty
  Component::IRC::Plugin::Connector
  Component::Server::TCP
  Filter::Stream
  Filter::SSL
);

use Data::Dumper;

use lib qw(../../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::Constants;

use POE::Component::IRC::Plugin qw( :ALL );
use App::IRC::Bot::Shoze::POE::IRC;
use App::IRC::Bot::Shoze::POE::WS;
use App::IRC::Bot::Shoze::POE::SubTask;


our $AUTOLOAD;

my %fields = (
    _parent => undef,

    IRC     => undef,
    WS      => undef,
    SubTask => undef,
);

sub new {
    my ( $proto, $parent ) = @_;
    DEBUG( "Creating new " . __PACKAGE__ );
    croak "No parent specified" unless ref $parent;
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    $s->_parent($parent);
   
    $s->IRC( new App::IRC::Bot::Shoze::POE::IRC($s));
    $s->SubTask( new App::IRC::Bot::Shoze::POE::SubTask($s) );
    $s->WS( new App::IRC::Bot::Shoze::POE::WS($s) );
    return $s;
}

sub run {
    LOG("[POE] starting\n");
    $poe_kernel->run();
}

sub stop {
    LOG("[POE] starting\n");
    $poe_kernel->stop();
}
1;
