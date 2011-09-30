package App::IRC::Bot::Shoze::HTTP::User::Main;

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

use lib qw(../../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::HTTP::Helper qw(bad_request);

our $AUTOLOAD;

our %fields = (
    _parent  => undef,
    _Network => undef,
    _Channel => undef,
    user     => undef,
    info     => undef,

);

=head1 SUBROUTINES/METHODS

=over

=item new

=cut

sub new {
    my ( $proto, $parent, $Network, $Channel ) = @_;
    DEBUG( "Creating new " . __PACKAGE__, 5 );
    croak "No parent specified" unless ref $parent;
    my $class = ref($proto) || $proto;
    my $s = {
              _permitted => \%fields,
              %fields,
    };
    bless( $s, $class );
    $s->_parent($parent);
    $s->_Network($Network);
    $s->_Channel($Channel);
    $s->info(new App::IRC::Bot::Shoze::HTTP::Network::Channel::Info($s));
    $s->user(new App::IRC::Bot::Shoze::HTTP::Network::Channel::User($s));
    return $s;
}

=item is_valid_ressource

=cut

sub is_valid_ressource {
    my ( $s, $paths, $n ) = @_;
    LOG( "Channel: " . $paths->[$n] );
    return $s->_Channel;
}

=item give

=cut

sub give {
    my ( $s, $request, $paths, $n ) = @_;
    my $r  = HTTP::Response->new(200);
    my $db = App::IRC::Bot::Shoze::Db->new;

    my @L;
    for my $k(keys %$s) {
        next if $k =~ /^_/;
        push @L, $k;
    }
    $r->push_header( 'Content-type', 'text/html' );
    $r->content( Dump( \@L) );
    return $r;
}

=item request

=cut

sub request {
    my ( $s, $request, $paths, $n ) = @_;
    if ( $request->uri->path eq '/' ) {
        return $s->give_root($request);
    }
    unless ($paths) {
        my @paths = split( m#/+#, $request->uri->path );
        $paths = \@paths;
        $n     = 1;
    }
    LOG( "Checking path: " . $paths->[$n] );

    if ( ( $n + 1 ) == @$paths ) {
        LOG("Request end");
        return $s->give( $request, $paths, $n );
    } else {
        LOG( "Continue request: " . $paths->[ $n + 1 ] );
        unless ( defined $s->{ $paths->[$n + 1] } ) {
            return $s->bad_request("Invalid ressource");
        }
        return $s->{ $paths->[$n + 1] }->request( $request, $paths, $n + 1 );
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
