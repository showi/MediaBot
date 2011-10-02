package App::IRC::Bot::Shoze::Db::NetworkChannels::Object;

=head1 NAME

App::IRC::Bot::Shoze::Db::NetworkChannels::Object - Store one row from SQL database

=cut

=head1 SYNOPSIS
    
Store row from SQL database

=cut

use strict;
use warnings;

use Carp;

use lib qw(../../../../../../);
use App::IRC::Bot::Shoze::Class qw(DESTROY);
use App::IRC::Bot::Shoze::Db::SynchObject qw(:ALL);
use App::IRC::Bot::Shoze::Log;

our $AUTOLOAD;

our %fields = (
    bot_mode        => undef,
    mode            => undef,
    bot_joined      => undef,
    password        => undef,
    auto_topic      => undef,
    ulimit          => undef,
    id              => undef,
    auto_op         => undef,
    owner           => undef,
    topic           => undef,
    topic_setby     => undef,
    topic_seton     => undef,
    auto_voice      => undef,
    name            => undef,
    active          => undef,
    auto_mode       => undef,
    type            => undef,
    network_id      => undef,  
    wanted_mode     => undef,
    wanted_topic    => undef,
    wanted_password => undef,
    wanted_ulimit   => undef,
    created_by => undef,
    
    created_on      => undef,
    updated_on => undef,

    _object_name => undef,
    _object_db   => undef,
);

=head1 SUBROUTINES/METHODS

=over

=item new

=cut

sub new {
    my ( $proto, $object_db ) = @_;
    DEBUG( "Creating new " . __PACKAGE__, 8 );
    croak "No database object passed as first parameter"
      unless ref($object_db);
    my $class = ref($proto) || $proto;
    my $s = {
              _permitted => \%fields,
              %fields,
    };
    bless( $s, $class );
    $s->_init_fields;    # DIRTY HACK
    $s->_object_name('network_channels');
    $s->_object_db($object_db);
    return $s;
}

=item _usable_name

=cut

sub _usable_name {
    my $s = shift;
    return $s->type . $s->name;

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
