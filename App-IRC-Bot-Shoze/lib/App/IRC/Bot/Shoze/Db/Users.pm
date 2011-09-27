package App::IRC::Bot::Shoze::Db::Users;

=head1 NAME

App::IRC::Bot::Shoze::Db::Users - Methods for easy SQL table access

=cut

=head1 SYNOPSIS
    
Easy SQL table access

=cut

use strict;
use warnings;

use Carp;

use IRC::Utils qw(:ALL);
use Crypt::Passwd::XS;

use lib qw(../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Db::Users::Object qw();
use App::IRC::Bot::Shoze::Log;

our $AUTOLOAD;

our %fields = (
    _handle => undef,
    _parent => undef,
);

=head1 SUBROUTINES/METHODS

=over

=item new

=cut

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

=item list

=cut

sub list {
    my $s = shift;
    my $C = new App::IRC::Bot::Shoze::Db::Users::Object( $s->_parent );
    return $C->_list();
}

=item get

=cut

sub get {
    my ( $s, $id ) = @_;
    DEBUG( __PACKAGE__ . "::get($id)", 3);
    my $C = new App::IRC::Bot::Shoze::Db::Users::Object( $s->_parent );
    return $C->_get( $id );
}

=item get_by

=cut

sub get_by {
    my ( $s, $hash ) = @_;
    DEBUG( __PACKAGE__ . "::get_by($hash)", 3);
    my $C = new App::IRC::Bot::Shoze::Db::Users::Object( $s->_parent );
    return $C->_get_by( $hash );
}

=item create

=cut

sub create {
    my ( $s, $name, $password, $hostmask ) = @_;
    my $C = new App::IRC::Bot::Shoze::Db::Users::Object( $s->_parent );
    my $Config = App::IRC::Bot::Shoze::Config->new;
    my $salt = $Config->bot->{password_salt};
    $C->name($name);
    $C->password(Crypt::Passwd::XS::crypt( $password, $salt ));
    print "Create: $hostmask\n";
    $C->hostmask($hostmask);
    $C->pending(1);
    $C->lvl(200);
    $C->is_bot(0);
    $C->created_on(time);
    return $C->_create();
}

=item check_password

=cut

sub check_password {
    my ( $s, $User, $password ) = @_;
    $s->_parent->die_if_not_open();
    croak "Need User object as first parameter"
      if ( not defined $User or not ref($User) );
    my $Config = App::IRC::Bot::Shoze::Config->new;
    my $salt = $Config->bot->{password_salt};
    my $encrypted = Crypt::Passwd::XS::crypt( $password, $salt );
    if ( $User->password eq $encrypted ) {
        return 1;
    }
    return 0;
}

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2011 Joachim Basmaison.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;
