#!/usr/bin/perl -W

use strict;
use warnings;

use lib qw(.);

use MediaBot;

my $b = new MediaBot("./");
print "DB USER: " . $b->Config->db->{user} . "\n";
$b->Irc->run();