package App::IRC::Bot::Shoze::HTTP::Helper;

=head1 NAME

App::IRC::Bot::Shoze::HTTP::Channels

=cut

=head1 SYNOPSIS

=cut

use strict;
use warnings;

use Carp;

use Carp;

=head1 EXPORT_OK

=over

=item bad_request

=back

=cut

use Exporter;
use Encode qw(decode);

our @TAGS        = qw(request bad_request is_valid_ressource);
our @ISA         = qw(Exporter);
our @EXPORT_OK   = @TAGS;
our %EXPORT_TAGS = ( ALL => [@TAGS] );
use HTTP::Response;

use lib qw(../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Log;

=head1 SUBROUTINES/METHODS

=over

=item bad_request 

=cut

sub bad_request {
    my ( $s, $msg ) = @_;
    my $r = HTTP::Response->new( 400, "Malformed request!" );
    $r->push_header( 'Content-type', 'text/html' );
    $r->content($msg);
    return $r;
}

=item is_valid_ressource

=cut

sub is_valid_ressource {
    my ( $s, $paths, $n ) = @_;
    return 0 unless defined $s->{ $paths->[$n] };
    return 1;
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
    unless ( $s->is_valid_ressource( $paths, $n ) ) {
        return $s->bad_request( "Invalid ressource: " . $paths->[$n] );
    }
    if ( ( $n  ) == @$paths ) {
        LOG("Request end");
        return $s->give( $request, $paths, $n );
    } else {
        LOG("Continue request: " . $paths->[$n + 1]);
        unless ( defined $s->{ $paths->[$n] } ) {
            return $s->bad_request("Invalid ressource");
        }
        return $s->{ $paths->[$n] }->request( $request, $paths, $n + 1 );
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
