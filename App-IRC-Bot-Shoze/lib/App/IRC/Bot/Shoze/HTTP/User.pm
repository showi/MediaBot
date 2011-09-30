package App::IRC::Bot::Shoze::HTTP::User;

=head1 NAME

App::IRC::Bot::Shoze::HTTP::Channels

=cut

=head1 SYNOPSIS

=cut

use strict;
use warnings;

use Carp;

use HTTP::Response;
use YAML qw'freeze thaw Bless Dump';
use URI::Escape::XS;

use lib qw(../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::HTTP::Helper qw(bad_request);
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Helper qw(splitchannel);

our $AUTOLOAD;

our %fields = ( _parent => undef, _User => undef );

=head1 SUBROUTINES/METHODS

=over

=item new

=cut

sub new {
    my ( $proto, $parent ) = @_;
    DEBUG( "Creating new " . __PACKAGE__, 5 );
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

=item is_valid_ressource

=cut

sub is_valid_ressource {
    my ( $s, $paths, $n ) = @_;
    LOG("Testing network ressource");

}

=item give

=cut

sub give {
    my ( $s, $request, $paths, $User) = @_;
    my $r  = HTTP::Response->new(200);

    $r->push_header( 'Content-type', 'text/html' );
    $r->content( Dump( $User->_serializable) );
    return $r;
}

=item request

=cut

sub request {
    my ( $s, $request, $paths, $n ) = @_;
    unless ($paths) {
        return $s->bad_request("Invalid object usage");
    }
    LOG( "Checking path: " . $paths->[$n] );
    my $db   = App::IRC::Bot::Shoze::Db->new;
    my $User = $db->Users->get_by({name => $paths->[$n]});
    unless($User) {
        return $s->bad_request("Invalid user: " . $paths->[$n]);
    }
    if ( ($n) == @$paths ) {
        LOG("Request end (User)");
        return $s->give( $request, $paths, $n, $User);
    } else {
        LOG( "Continue request: " . $paths->[ $n + 1 ] );

#        my $name = decodeURIComponent( $paths->[ $n + 1 ] );
#
#        my $User = $db->NetworkChannels->get_by( { name => $name } );
#        unless ($User) {
#            return $s->bad_request("Bad use name: $name");
#        }
#        my $RC =
#          new App::IRC::Bot::Shoze::HTTP::User::Main( $s, $Network, $User );
#        return $RC->request( $request, $paths, $n + 1 );
    }
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
