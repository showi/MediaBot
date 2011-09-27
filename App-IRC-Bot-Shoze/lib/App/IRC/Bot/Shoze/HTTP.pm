package App::IRC::Bot::Shoze::HTTP;


=head1 NAME

App::IRC::Bot::Shoze::HTTP - REST interface between the bot and the world

=cut

=head1 SYNOPSISt

    # Restfull authentication
    # http://broadcast.oreilly.com/2009/12/principles-for-standardized-rest-authentication.html

=cut


use strict;
use warnings;

use Carp;

use HTTP::Response;
use HTTP::Request;
use Digest::HMAC;
use Digest::SHA256;
use Digest::SHA;
use YAML qw'freeze thaw Bless';
use URI qw(URI);

use lib qw(../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::HTTP::Channels;

our $AUTOLOAD;

our %fields = (
    _parent  => undef,
    Channels => undef,
);

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
    $s->Channels( new App::IRC::Bot::Shoze::HTTP::Channels($s) );
    return $s;
}

=item request

=cut
sub request {
    my ( $s, $host, $port, $ressource, $action, $apikey, $apikey_private, $format ) = @_;

    $format = 'html' unless $format;

    my @dactions = qw(get create delete list);
    croak "Invalid action $action"
      unless grep ( $action, @dactions );
    LOG("Building HTTP Request for ressource $ressource with action $action");
    my $r   = new HTTP::Request;
    my $uri = new URI();
    $uri->scheme('https');
    $uri->host("$host:$port");
    $uri->path("$ressource");

    if ( $action eq 'list' ) {
        $r->method('GET');
    }
    $uri->query_form(
        [
            apikey    => $apikey,
            format    => $format,
            timestamp => time,
        ]
    );
    my $str;
    my $tosign = $uri->path . $uri->query;
    my $hmac = Digest::HMAC->new( $apikey_private, "Digest::SHA" );
    $hmac->add($tosign);
    my $signature = $s->sign_uri( $uri, $apikey_private );
    $uri->query_form(
        [
            apikey    => $apikey,
            format    => $format,
            timestamp => time,
            signature => $signature,
        ]
    );
    $r->uri($uri);
    $r->header( "content-type" => 'text/html' );
    return $r;

}

=item bad_request_noapikey

=cut

sub bad_request_noapikey {
    my $s = shift;
    my $r = HTTP::Response->new( 400, "No API key" );
    $r->push_header( 'Content-type', 'text/html' );
    $r->content( "
        Malformed request<br>
        no API key provided   
    " );
    return $r;
}

=item bad_request_invalidapikey

=cut

sub bad_request_invalidapikey {
    my $s = shift;
    my $r = HTTP::Response->new( 400, "Invalid API key" );
    $r->push_header( 'Content-type', 'text/html' );
    $r->content( "
        Malformed request<br>
        Invalid api key   
    " );
    return $r;
}

=item bad_request_badsignature

=cut

sub bad_request_badsignature {
    my $s = shift;
    my $r = HTTP::Response->new( 400, "Bad signature" );
    $r->push_header( 'Content-type', 'text/html' );
    $r->content( "
        Malformed request<br>
        Invalid api key   
    " );
    return $r;
}

=item bad_request_timegone

=cut

sub bad_request_timegone {
    my $s = shift;
    my $r = HTTP::Response->new( 400, "Bad signature" );
    $r->push_header( 'Content-type', 'text/html' );
    $r->content( "
        Invalid request<br>
        A matter of time i guess   
    " );
    return $r;
}

=item sign_uri

=cut

sub sign_uri {
    my ( $s, $uri, $key ) = @_;
    croak "No uri provided!" unless $uri;
    croak "No key provided!" unless $key;
    my %params = $uri->query_form;
    my $tosign = $uri->path . "?";
    my $signature;
    for my $k ( sort keys %params ) {
        if ( $k eq "signature" ) {
            $signature = $params{$k};
        }
        else {
            $tosign .= "$k=" . $params{$k} . "&";
        }
    }
    my $hmac = Digest::HMAC->new( $key, "Digest::SHA" );
    $hmac->add($tosign);
    my $insignature = $hmac->hexdigest;
    return $insignature;
}

=item dispatch

=cut

sub dispatch {
    my ( $s, $http_request ) = @_;

    my $uri   = $http_request->uri;    #URI->new( $http_request->uri );
        LOG("Get HTTP request: $uri");
    my %param = $uri->query_form;

    my $time = time;
    my $diff = $time - $param{'timestamp'};

    if ( not defined $param{'timestamp'} or $diff > 500 ) {
        return $s->bad_request_timegone;
    }

    unless ( $param{'apikey'} ) {
        return $s->bad_request_noapikey;
    }

    my $db = $s->_parent->Db;
    my $User = $db->Users->get_by( { apikey => $param{apikey} } );
    return $s->bad_request_invalidapikey unless ($User);

    my $insignature = $s->sign_uri( $uri, $User->apikey_private );
    return $s->bad_request_badsignature
      unless ( $param{signature} eq $insignature );

    $http_request->uri->path =~ m|^[\w\d/_-]+$|
      or do {
        LOG ("Bad request\n");
        my $r = HTTP::Response->new( 400, "Malformed request!" );
        $r->push_header( 'Content-type', 'text/html' );
        $r->content( "
        Malformed request<br>
        Format:
        /[ressource/][id/]><br> 
        It's a restful API, use GET, PUT, DELETE ...   
    " );
        return $r;
      };
    my ( $ressource, $id ) = ( $2, $4 );
    my $module = ucfirst($ressource);
    unless ( exists $s->{_permitted}->{$module} ) {
        my $r = HTTP::Response->new( 404, "Invalid ressource" );
        $r->push_header( 'Content-type', 'text/html' );
        $r->content( "
        Invalid ressource: $ressource<br>   
    " );
        return $r;
    }
    my $msg;
    my $response = HTTP::Response->new(200);
    $response->push_header( 'Content-type', 'text/html' );

    if ( defined $id ) {
        if ( $http_request->method =~ /^(GET|HEAD)$/ ) {
            $msg .= "GET ressource $ressource with ID $id\n<br>";

        }
        elsif ( $http_request->method eq "PUT" ) {
            $msg .= "EDIT ressource $ressource with ID $id\n<br>";
        }
        elsif ( $http_request->method eq "DELETE" ) {
            $msg .= "DELETE ressource $ressource with ID $id\n<br>";
        }
    }
    else {
        if ( $http_request->method =~ /^(GET|HEAD)$/ ) {
            $msg .= "LIST ressource $ressource\n<br>";
            return $s->$module->list( $User, $response );
        }
        elsif ( $http_request->method eq "PUT" ) {
            $msg .= "CREATE ressource $ressource\n<br>";
        }
        elsif ( $http_request->method eq "DELETE" ) {
            $msg .= "ERROR ressource $ressource with ID $id\n<br>";
        }
    }
    my $r = HTTP::Response->new(200);
    $r->push_header( 'Content-type', 'text/html' );
    $r->content($msg);
    return $r;
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
