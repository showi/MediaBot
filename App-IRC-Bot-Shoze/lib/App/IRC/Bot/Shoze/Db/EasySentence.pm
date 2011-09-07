package App::IRC::Bot::Shoze::Db::EasySentence;

use strict;
use warnings;

use Carp;

use IRC::Utils qw(:ALL);

use lib qw(../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Db::EasySentence::Object qw();
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
    DEBUG( "Creating new " . __PACKAGE__ , 4);
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
    my ($s, $name) = @_;
    croak "Need a name to acces sentence list" 
        unless $name;
    my $C = new App::IRC::Bot::Shoze::Db::EasySentence::Object( $s->_parent, $name);
    return $C->_list();
}

sub get {
    my ( $s, $id ) = @_;
    DEBUG( __PACKAGE__ . "::get($id)", 3);
    my $C = new App::IRC::Bot::Shoze::Db::Apero::Object( $s->_parent );
    return $C->_get( $id );
}

sub get_by {
    my ( $s, $hash ) = @_;
    DEBUG( __PACKAGE__ . "::get_by($hash)", 3);
    my $C = new App::IRC::Bot::Shoze::Db::Apero::Object( $s->_parent );
    return $C->_get_by( $hash );
}

sub create {
    my ( $s, $trigger, $text) = @_;
    my $A = new App::IRC::Bot::Shoze::Db::Apero::Object( $s->_parent );
    $A->trigger($trigger);
    $A->text($text);
    return $A->_create();
}


1;
