package App::IRC::Bot::Shoze::HTTP::Network;

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

use App::IRC::Bot::Shoze::HTTP::Network::Channel;

our $AUTOLOAD;

our %fields = ( _parent => undef, );

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
    my $db = App::IRC::Bot::Shoze::Db->new;
    return $db->Networks->get_by( { name => $paths->[$n] } );
}

=item give

=cut

sub give {
    my ( $s, $request, $paths, $n, $N ) = @_;
    my $r  = HTTP::Response->new(200);
    my $db = App::IRC::Bot::Shoze::Db->new;
    #my $N  = $db->Networks->get_by( { name => $paths->[$n] } );

    my @CL = $db->NetworkChannels->list($N);
    my @NCL;
    for my $channel (@CL) {
        my $hash;
        for my $k ( keys %{$channel} ) {
            next if $k =~ /^_/;
            $hash->{$k} = $channel->{$k};
        }

        #$hash->{rest_url} = '/network/' . $hash->{name};
        push @NCL, $hash;
    }
    print Dump @NCL;

    $r->push_header( 'Content-type', 'text/html' );
    $r->content( Dump( \@NCL ) );
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
    LOG("Checking path: " . $paths->[$n]);
    my $Network = $s->is_valid_ressource( $paths, $n );
    unless ( $Network ) {
        return $s->bad_request( "Invalid ressource: " . $paths->[$n] );
    }
    if ( ( $n + 1 ) == @$paths ) {
        LOG("Request end");
        return $s->give( $request, $paths, $n, $Network );
    } else {
        LOG("Continue request: " . $paths->[$n + 1]);
        my $db = App::IRC::Bot::Shoze::Db->new;
        my $channel = decodeURIComponent($paths->[$n + 1]);
        my ($ctype, $cname) = splitchannel($channel);
        my $Channel = $db->NetworkChannels->get_by($Network, {type => $ctype, name => $cname } );
        unless ( $Channel ) {
            return $s->bad_request("Bad channel name: $cname");
        }
        my $RC = new App::IRC::Bot::Shoze::HTTP::Network::Channel($s, $Network, $Channel);
        return $RC->request( $request, $paths, $n + 1 );
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
