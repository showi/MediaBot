package App::IRC::Bot::Shoze::Plugins::IRC::Apero::Db;

=head1 NAME

App::IRC::Bot::Shoze::Db::Apero - Methods for easy SQL table access

=cut

=head1 SYNOPSIS
    
Easy SQL table access

=cut

use strict;
use warnings;

use Carp;

use IRC::Utils qw(:ALL);

use lib qw(../../../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Plugins::IRC::Apero::Db::Object;
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
    my $C = new App::IRC::Bot::Shoze::Plugins::IRC::Apero::Db::Object(  $s->_parent->_parent );
    return $C->_list();
}

=item get

=cut

sub get {
    my ( $s, $id ) = @_;
    DEBUG( __PACKAGE__ . "::get($id)", 3);
    my $C = new App::IRC::Bot::Shoze::Plugins::IRC::Apero::Db::Object( $s->_parent->_parent );
    return $C->_get( $id );
}

=item get_by

=cut

sub get_by {
    my ( $s, $hash ) = @_;
    DEBUG( __PACKAGE__ . "::get_by($hash)", 3);
    my $C = new App::IRC::Bot::Shoze::Plugins::IRC::Apero::Db::Object(  $s->_parent->_parent );
    return $C->_get_by( $hash );
}

=item create

=cut

sub create {
    my ( $s, $trigger, $text) = @_;
    my $A = new App::IRC::Bot::Shoze::Plugins::IRC::Apero::Db::Object(  $s->_parent->_parent );
    $A->trigger($trigger);
    $A->text($text);
    return $A->_create();
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
