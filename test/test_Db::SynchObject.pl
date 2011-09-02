#!/usr/bin/perl -W


package Dumb;

use Carp;

use lib qw(../);
use MediaBot::Class qw(AUTOLOAD DESTROY _get_root);
use MediaBot::Config;
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
    $s->_path("../");
    $s->Config( new MediaBot::Config($s) );
    $s->Db( new MediaBot::Db($s) );
    return $s;
}

1;

package main;

use strict;
use warnings;

use Carp;
use Data::Dumper;

use lib qw(..);

use MediaBot;
use MediaBot::Db::Channels;

my $Dumb = new Dumb();

my $chan = new MediaBot::Db::Channels( $Dumb->Db );
if ($chan->_get_by({type=>'#',name=>'roots'})) {
    print $chan->_pretty;    
}
$chan->auto_op(rand(10));
$chan->auto_topic(rand(10));
$chan->bot_mode(rand(10));
$chan->_update();
my $chan2 = new MediaBot::Db::Channels( $Dumb->Db );
if ($chan2->_get_by({type=>'#',name=>'roots'})) {
    print $chan2->_pretty;    
}

exit;

1;
__DATA__
#my $b = new MediaBot("../");
#my $d = $b->Db;

#my $Dumb = new MediaBot::Dumb();
my $so = new MediaBot::Db::SynchObject( "test", $Dumb->Db );
$so->get(1);
print "Name01:" . $so->name . "\n";

my $so2 = new MediaBot::Db::SynchObject( "test", $Dumb->Db );
$so2->get_by( { name => $so->name } );
print "Name02:" . $so2->name . "\n";

#print Dumper $so2;

my $chan = new MediaBot::Db::SynchObject( "channels", $Dumb->Db );
my $res = $chan->get_by( { type => '#', name => 'roots' } );
croak "No channel" unless $res;
print $chan->pretty . "\n";
$chan->auto_op(1);
$chan->auto_topic(1);
$chan->update();

my $chan2 = new MediaBot::Db::SynchObject( "channels", $Dumb->Db );
my $res2 = $chan2->get_by( { type => '#', name => 'roots' } );
croak "No channel" unless $res2;
print $chan2->pretty . "\n";
exit;

