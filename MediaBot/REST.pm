package MediaBot::REST;
# Restfull authentication 
# http://broadcast.oreilly.com/2009/12/principles-for-standardized-rest-authentication.html
use strict;
use warnings;

use Carp;

use HTTP::Response;
use URI qw(URI);

use lib qw(../);
use MediaBot::Class qw(AUTOLOAD DESTROY _get_root);
use MediaBot::Log;
use MediaBot::REST::Channels;

our $AUTOLOAD;

our %fields = (
    _parent  => undef,
    Channels => undef,
);

# Constructor
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
    $s->Channels( new MediaBot::REST::Channels($s) );
    return $s;
}

sub dispatch {
    my ( $s, $http_request ) = @_;
    my $uri = URI->new($http_request->uri);
    print "Scheme    : " . $uri->scheme . "\n";
    print "Opaque    : " . $uri->opaque . "\n";
    print "Path      : " . $uri->path . "\n";
    print "Fragment  : " . $uri->fragment . "\n";
    print "Path      : " . $uri->path . "\n";
    print "Path Query: " . $uri->path_query . "\n";
    print " Query    : " . $uri->query . "\n";
    my %param = $uri->query_form;
    for my $k(sort keys %param) {
        print "Param : $k => " . $param{$k} . "\n";
    }
#    print " Host    : " . $uri->host . "\n";
#    print " Port    : " . $uri->port . "\n";
    $http_request->uri =~ m|^/(([\w\d][\w\d_-]*)/)(([\d]+)/)?$|
      or do {
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
        }
        elsif ( $http_request->method eq "PUT" ) {
            $msg .= "CREATE ressource $ressource\n<br>";
        }
        elsif ( $http_request->method eq "DELETE" ) {
            $msg .= "ERROR ressource $ressource with ID $id\n<br>";
        }
    }
    my $r = HTTP::Response->new( 200 );
        $r->push_header( 'Content-type', 'text/html' );
        $r->content( $msg );
    return $r;#s->$module->process_request( $http_request, $id );
}

1;
