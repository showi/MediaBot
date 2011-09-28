#!/usr/bin/perl 

use warnings;
use strict;

use LWP::UserAgent;
use HTTP::Request;
use XML::Simple;
use Data::Dumper;
use YAML qw(Dump Bless);

use lib qw(../lib/);
use App::IRC::Bot::Shoze;

my $user     = "";
my $password = "";
my $hostname = "";
my $port     = 0;

my $netloc   = "$hostname:$port";
my $url      = "http://$netloc/admin/stats.xml";
my $realm    = 'Icecast2 Server';

my $ua = new LWP::UserAgent;
$ua->agent($App::IRC::Bot::Shoze::PROGRAMNAME . " / " . $App::IRC::Bot::Shoze::VERSION);
$ua->credentials( $netloc, $realm, $user, $password );
my $request = HTTP::Request->new( GET => $url );
my $response = $ua->request($request);
unless ( $response->is_success ) {
    my $ref = { status_msg => $response->status_line, };
    print Dump $ref;
    exit 1;
}
my @array_tags;
my $xmls = new XML::Simple(
    ForceArray    => \@array_tags,
    KeyAttr       => [],
    KeepRoot      => 1,
    SuppressEmpty => ''
);
my $ref = $xmls->XMLin( $response->decoded_content );
$ref->{status_msg} = $response->status_line;
print Dump $ref;
exit 0;
