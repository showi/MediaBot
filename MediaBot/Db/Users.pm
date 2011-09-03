package MediaBot::Db::Users;

use strict;
use warnings;

use Carp;

use IRC::Utils qw(:ALL);
use Crypt::Passwd::XS;

use lib qw(../../);
use MediaBot::Class qw(AUTOLOAD DESTROY _get_root);
use MediaBot::Db::Users::Object qw();
use MediaBot::Log;

our $AUTOLOAD;

our %fields = (
    _handle => undef,
    _parent => undef,
);

# Constructor
#############
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
    return $s;
}

sub list {
    my $s = shift;
    my $C = new MediaBot::Db::Users::Object( $s->_parent );
    return $C->_list();
}

sub get {
    my ( $s, $id ) = @_;
    LOG( __PACKAGE__ . "::get($id)" );
    my $C = new MediaBot::Db::Users::Object( $s->_parent );
    return $C->_get( $id );
}

sub get_by {
    my ( $s, $hash ) = @_;
    LOG( __PACKAGE__ . "::get_by($hash)" );
    my $C = new MediaBot::Db::Users::Object( $s->_parent );
    return $C->_get_by( $hash );
}

sub create {
    my ( $s, $name, $password, $hostmask ) = @_;
    my $C = new MediaBot::Db::Users::Object( $s->_parent );
    my $salt = $s->_get_root->Config->bot->{password_salt};
    $C->name($name);
    $C->password(Crypt::Passwd::XS::crypt( $password, $salt ));
    $C->hostmask($hostmask);
    return $C->_create();
}

sub check_password {
    my ( $s, $User, $password ) = @_;
    $s->_parent->die_if_not_open();
    croak "Need User object as first parameter"
      if ( not defined $User or not ref($User) );
    my $salt = $s->_get_root->Config->bot->{password_salt};
    my $encrypted = Crypt::Passwd::XS::crypt( $password, $salt );
    if ( $User->password eq $encrypted ) {
        return 1;
    }
    return 0;
}

1;
