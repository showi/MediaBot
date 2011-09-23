#!/usr/bin/perl 

use warnings;
use strict;

use LWP::UserAgent;
use HTTP::Request;
use XML::Simple;
use Data::Dumper;
use YAML qw(Dump Bless);

my $user     = "admin";
my $password = "";
my $hostname = "radiocapsule.com";
my $port     = 15000;

my $netloc = "$hostname:$port";
my $url    = "http://$netloc/admin/stats.xml";
my $realm    = 'Icecast2 Server';

my $ua = new LWP::UserAgent;
$ua->agent("Shoze/0.0.7");
$ua->credentials( $netloc, $realm, $user, $password );
my $request = HTTP::Request->new( GET => $url );
my $response = $ua->request($request);
unless ( $response->is_success ) {
    my $status = $response->status_line;
    print "1#$status";
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
print Dump $ref;
exit 0;
