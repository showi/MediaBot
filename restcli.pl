#!/usr/bin/perl 

package Dumb;

use Carp;

use lib qw(../);
use MediaBot::Class qw(AUTOLOAD DESTROY _get_root);
use MediaBot::Config;
use MediaBot::Db;
use MediaBot::REST;

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
    $s->_path("");
    $s->Config( new MediaBot::Config($s) );
    $s->Db( new MediaBot::Db($s) );
    $s->REST( new MediaBot::REST($s) );
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

my $apikey         = "2Efke33F";
my $apikey_private = "nd39GDsQAlKmAqDfVbnXdRtp03fBC653";

my $ua = LWP::UserAgent->new(
    agent    => "restcli 0.1",
    ssl_opts => { verify_hostname => 0 }
);

sub channel_list {
    my $msg = "Listing channel:\n";
    my $request =
      $Dumb->REST->request( 'channels', 'list', $apikey, $apikey_private );
    my $response = $ua->request($request);

    if ( $response->is_success ) {
        my $res = $response->decoded_content;
        #print "Res: $res\n";
        my @channels = thaw($res);    # or whatever
        for my $chan (@channels) {
            for ( @{$chan} ) {
                #print "ẑef: $_\n";
                print "Name: "
                  . $_->{type}
                  . $_->{name} . "("
                  . $_->{owner} . ")\n";
            }
        }
    }
    else {
        die $response->status_line;
    }
    print $msg;
    return 0;
}

use Term::ShellUI;
my $term = new Term::ShellUI(
    commands => {
        "c" => {
            desc    => "listing channel",
            maxargs => 0,

            #args    => #sub { shift->complete_onlydirs(@_); },
            proc => sub { channel_list; },
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
