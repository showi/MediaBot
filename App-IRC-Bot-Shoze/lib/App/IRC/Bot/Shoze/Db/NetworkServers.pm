package App::IRC::Bot::Shoze::Db::NetworkServers;

use strict;
use warnings;

use Carp;

use IRC::Utils qw(:ALL);

use lib qw(../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Db::NetworkServers::Object qw();
use App::IRC::Bot::Shoze::Log;

our $AUTOLOAD;

our %fields = (
    _handle => undef,
    _parent => undef,
);

# Constructor
#############
sub new {
    my ( $proto, $parent ) = @_;
    DEBUG( "Creating new " . __PACKAGE__ , 8);
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

sub list {
    my ($s, $Network) = @_;
    croak "Need Network object as first parameter "
      unless ref($Network) =~ /Db::Networks::Object/;
    my $hash = { network_id => $Network->id};
    my $C = new App::IRC::Bot::Shoze::Db::NetworkServers::Object( $s->_parent );
    return $C->_list_by($hash);
}

sub get {
    my ( $s, $id ) = @_;
    DEBUG( __PACKAGE__ . "::get($id)", 3);
    my $C = new App::IRC::Bot::Shoze::Db::NetworkServers::Object( $s->_parent );
    return $C->_get( $id );
}

sub get_by {
    my ( $s, $hash ) = @_;
    DEBUG( __PACKAGE__ . "::get_by($hash)", 3);
    my $C = new App::IRC::Bot::Shoze::Db::NetworkServers::Object( $s->_parent );
    return $C->_get_by( $hash );
}

sub create {
    my ( $s, $trigger, $text) = @_;
    my $A = new App::IRC::Bot::Shoze::Db::NetworkServers::Object( $s->_parent );
    $A->trigger($trigger);
    $A->text($text);
    return $A->_create();
}


1;
