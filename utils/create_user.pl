#!/usr/bin/perl

use strict;
use warnings;

use Carp;

use lib qw(..);

use MediaBot;

sub usage {
    print <<EOF
./create_user [username{3,9}] [password{6,16}]
    character set: a-z A-Z 0-9 _-
EOF
}
open STDERR, '>/dev/null';

#$MediaBot::Log::logfile = "/dev/null";
$MediaBot::DEBUG        = 0;
my $b = new MediaBot("../");

my $d = $b->Db;
if ( @ARGV < 2 ) {
    usage();
    exit 1;
}

unless ( $ARGV[0] =~ /^[a-z0-9_-]{3,9}$/i ) {
    print "Invalid username\n";
    usage();
    exit 2;
}

unless ( $ARGV[1] =~ /^[a-z0-9_-]{6,16}$/i ) {
    print "Invalid password\n";
    usage();
    exit 2;
}

print "Creating user " . $ARGV[0] . ": ";
my $err = $d->Users->create( $ARGV[0], $ARGV[1], 0); 
if ($err) { print "Fail\n"; exit 3 }
else      { print "Ok\n"; exit 0;}

1;
