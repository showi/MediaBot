#!/usr/bin/perl 

package Dumb;

use Carp;

use lib qw(../);
use MediaBot::Class qw(AUTOLOAD DESTROY _get_root);
use MediaBot::Config;
use MediaBot::Db;
our $AUTOLOAD;

our %fields = (
    _path  => undef,
    Config => undef,
    Db     => undef,
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
    return $s;
}
1;

package main;

use strict;
use warnings;

use LWP::UserAgent;
my $Dumb = new Dumb();

my $ua = LWP::UserAgent->new( agent => "restcli 0.1",
 ssl_opts => { verify_hostname => 0});

sub channel_list {
    my $msg = "Listing channel:\n";
    my $response = $ua->get('https://localhost:9090/channels/');
 
 if ($response->is_success) {
     print $response->decoded_content;  # or whatever
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
        "channel.list" => {
            desc    => "listing channel",
            maxargs => 0,
            #args    => #sub { shift->complete_onlydirs(@_); },
            proc    => sub { channel_list; },
        },
        "chdir" => { alias => 'cd' },
        "pwd"   => {
            desc    => "Print the current working directory",
            maxargs => 0,
            proc    => sub { system('pwd'); },
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
