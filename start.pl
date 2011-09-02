#!/usr/bin/perl -W

use strict;
use warnings;

use lib qw(.);

use MediaBot;
use MediaBot::Log;

my $b = new MediaBot("./");
LOG("--- Starting MediaBot ---");
$b->POE->run();
