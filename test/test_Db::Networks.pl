#!/usr/bin/perl -W

use strict;
use warnings;

use lib qw(..);

use MediaBot;

my $b = new MediaBot("../");
my $d = $b->Db;

my @networks = qw(Undernet Efnet Dalnet);

for(@networks) {
	print "Tring to create network [ $_ ]: ";
	my $err = $d->Networks->create($_, "$_ network");
	if ($err) { print "Fail" } else { print "Ok"} print "\n";
}	

#for(@networks) {
#	print "Tring to delete network [ $_ ]: ";
#	my $err = $d->Networks->delete($_);
#	if ($err) { print "Fail" } else { print "Ok"} print "\n";
#}

1;