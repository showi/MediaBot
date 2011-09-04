#!/usr/bin/perl -W

use strict;
use warnings;

use lib qw(.);

use App::IRC::Bot::Shoze;
use App::IRC::Bot::Shoze::Log;

$App::IRC::Bot::Shoze::Debug = 9;

$App::IRC::Bot::Shoze::Log::logfile = "/srv/shoze/log/shoze.log";
App::IRC::Bot::Shoze::Log::flush();

LOG("----- Starting Shoze -----");
my $b = new App::IRC::Bot::Shoze("/srv/shoze/");
$b->POE->run();
LOG("----- Shoze ended -----");

exit(0);

1;
