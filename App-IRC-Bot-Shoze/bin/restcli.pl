#!/usr/bin/perl 

package Dumb;

use Carp;

use lib qw(../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Config;
use App::IRC::Bot::Shoze::Db;
use App::IRC::Bot::Shoze::REST;

our $AUTOLOAD;

our %fields = (
    _path  => undef,
    Config => undef,
    Db     => undef,
    REST   => undef,
);

# Constructor
#############
sub new {
    my ($proto) = @_;

    #DEBUG( "Creating new " . __PACKAGE__ );
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    $s->_path("/srv/shoze/");
    $s->Config( new App::IRC::Bot::Shoze::Config($s) );
    $s->Db( new App::IRC::Bot::Shoze::Db($s) );
    $s->REST( new App::IRC::Bot::Shoze::REST($s) );
    return $s;
}
1;

package main;

use strict;
use warnings;

use URI qw(URI);
use LWP::UserAgent;
use YAML qw'freeze thaw Bless';

my $Dumb = new Dumb();

my $host = $ARGV[0] || "127.0.0.1";
my $port = $ARGV[1] || 9090;
my $apikey         = "2Efke33F";
my $apikey_private = "nd39GDsQAlKmAqDfVbnXdRtp03fBC653";

my $ua = LWP::UserAgent->new(
    agent    => "restcli 0.1",
    ssl_opts => { verify_hostname => 0 }
);

sub request {
    my ( $ressource, $action ) = @_;
    my $request =
    $Dumb->REST->request( $host, $port, $ressource, $action, $apikey, $apikey_private );
    my $response = $ua->request($request);
    if ( $response->is_success ) {
        my $res = $response->decoded_content;
        my $ref = thaw($res);
        return $ref;
    } else {
        print "Error: " . $response->status_line . "\n";
    }
    return undef;
}

use Term::ShellUI;
my $term = new Term::ShellUI(
    commands => {
        "c" => {
            desc    => "listing channel",
            maxargs => 0,
            proc    => sub { 
                if (my $r = request( 'channels', 'list' )) {
                    print "Listing channels:\n";
                    print "-----------------\n";
                    for (@{$r}) {
                        print " - " . $_->{type}.$_->{name} . " (" . $_->{user_name} . ")\n";
                    }
                } 
            
            },
        
        },

        "chdir" => { alias => 'cd' },
        "pwd"   => {
            desc    => "Print the current working directory",
            maxargs => 0,
            proc    => sub { system('pwd'); },
        },
        "d" => {
            desc    => "Print the current working directory",
            maxargs => 1,
            proc    => sub {
                my $uri = URI( $_[0] );

            },
        },
        "quit" => {
            desc    => "Quit this program",
            maxargs => 0,
            method  => sub { shift->exit_requested(1); },
        }
    },
    history_file => '~/.shellui-synopsis-history',
);
print 'Using ' . $term->{term}->ReadLine . "\n";
$term->run();
