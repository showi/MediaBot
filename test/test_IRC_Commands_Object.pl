#!/usr/bin/perl -W

use strict;
use warnings;

use Carp;

use lib qw(..);

use MediaBot::IRC::Commands::Object;
use MediaBot::Constants;

print "Const: " . IRCCMD_TYPE_PRV . "\n";
my $o = new MediaBot::IRC::Commands::Object;
$o->type(IRCCMD_TYPE_PRV);
$o->type(4);

#my $b = new MediaBot("../");
