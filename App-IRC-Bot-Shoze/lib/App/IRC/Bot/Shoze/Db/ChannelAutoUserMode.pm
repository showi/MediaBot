package App::IRC::Bot::Shoze::Db::ChannelAutoUserMode;

=head1 NAME

App::IRC::Bot::Shoze::Db::ChannelAutoUserMode - Methods for easy SQL table access

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
use App::IRC::Bot::Shoze::Db::ChannelAutoUserMode::Object qw();
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
    my $C = new App::IRC::Bot::Shoze::Db::ChannelAutoUserMode::Object( $s->_parent );
    return $C->_list();
}

=item list_by

=cut

sub list_by {
    my ($s, $hash) = @_;
    my $C = new App::IRC::Bot::Shoze::Db::ChannelAutoUserMode::Object( $s->_parent );
    return $C->_list_by($hash);
}

=item get

=cut

sub get {
    my ( $s, $id ) = @_;
    DEBUG( __PACKAGE__ . "::get($id)", 3);
    my $C = new App::IRC::Bot::Shoze::Db::ChannelAutoUserMode::Object( $s->_parent );
    return $C->_get( $id );
}

=item get_by

=cut

sub get_by {
    my ( $s, $hash ) = @_;
    DEBUG( __PACKAGE__ . "::get_by($hash)", 3);
    my $C = new App::IRC::Bot::Shoze::Db::ChannelAutoUserMode::Object( $s->_parent );
    return $C->_get_by( $hash );
}

=item create

=cut

sub create {
    my ( $s, $channel_id, $hostmask, $action, $time ) = @_;
    my $C = new App::IRC::Bot::Shoze::Db::ChannelAutoUserMode::Object( $s->_parent );
    $C->channel_id($channel_id);
    $C->hostmask($hostmask);
    $C->action($action);
    $C->time($time);
    return $C->_create();
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
