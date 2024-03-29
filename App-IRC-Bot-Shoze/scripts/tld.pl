#!/usr/bin/perl
#############################################
#
# Extract tld information from iana web site
#
#############################################
use strict;
use warnings;

use Carp;

use Encode qw(decode encode);
use Net::IDN::Encode ':all';

use YAML qw(Dump Bless);
require LWP::UserAgent;

my $SCRIPT_NAME = "tld";

my $otld = "";
my $tld  = "";

sub myexit {
    my ( $status, $type, $info ) = @_;
    my $ref = {
        tld_origin => $otld,
        tld_ascii  => $tld,
    };
    if ($status) {
        $ref->{status_msg} = $type;
    }
    else {
        $ref->{info} = $info if $info;
        $ref->{type} = $type;
    }
    print Dump $ref;
    exit $status;
}

unless ( $ARGV[0] ) {
    myexit( 1,
        $SCRIPT_NAME
          . 'require one argument, a top level domanin to match against' );
}

$otld = decode( 'utf8', $ARGV[0] );
$tld = domain_to_ascii($otld);

unless ( $tld =~ /^[\w\d-]{2,30}$/ ) {
    myexit( 1, $SCRIPT_NAME . ', invalid tld format "' . $tld . '"' );
}

my $ua = LWP::UserAgent->new;
$ua->timeout(10);
$ua->env_proxy;

my $url = 'http://www.iana.org/domains/root/db/' . lc($tld) . '.html';

my $response = $ua->get($url);

unless ( $response->is_success ) {
    myexit( 1,
            $SCRIPT_NAME
          . ', cannot get url: '
          . $url . '('
          . $response->status_line
          . ')' );
}

my $content = $response->decoded_content;    # or whatever

my ( $type, $info );
if ( $content =~
/<p>\((((Restricted )?Generic)|Sponsored|Infrastructure|Test) top-level domain\)<\/p>/i
  )
{
    $type = $1;
}
elsif (
    $content =~ /<p>\((.*) top-level domain designed for <b>(.*)<\/b>\)<\/p>/ )
{
    ( $type, $info ) = ( $1, $2 );
}
else {
    print STDERR;
    myexit( 1,
            $SCRIPT_NAME
          . ', cannot extract information from iana web site for TLD '
          . $tld );
}

myexit( 0, $type, $info );

1;
