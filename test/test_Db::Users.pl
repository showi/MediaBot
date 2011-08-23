#!/usr/bin/perl -W

use strict;
use warnings;

use Carp;

use lib qw(..);

use MediaBot;

my $b = new MediaBot("../");
my $d = $b->Db;

my @users = qw(nami pomlom soze havier toto);

for(@users) {
	print "Tring to create user [ $_ ]: ";
	my $err = $d->Users->create($_, "xDgoOODldm", int(rand(1000)));
	if ($err) { print "Fail" } else { print "Ok"} print "\n";
}	
for(@users) {
	print "Tring to create user [ $_ ]: ";
	my $err = $d->Users->create($_, "xDgoOODldm", int(rand(1000)));
	if ($err) { print "Fail" } else { print "Ok"} print "\n";
}	

for(@users) {
	print "Tring to delete user [ $_ ]: ";
	my $id = $d->Users->get_id($_);
	croak "No user named $_ in database" unless defined $id;
	my $err = $d->Users->delete($id);
	if ($err) { print "Fail" } else { print "Ok"} print "\n";
}

my $password = "hGDlZpDDvDzqaetTpO";
my $err = $d->Users->create($users[0], $password, int(rand(1000)));
if ($err) { print "Fail"; exit 1; } else { print "Ok"} print "\n";
my $id = $d->Users->get_id($users[0]);
croak "No user named $users[0] in database!" unless $id;
my $U = $d->Users->get($id);
print "Name: " . $U->name . "\n" if $U;

if ($d->Users->check_password($U, $password)) {
	print "Password match!\n";
} else  {
	print "Password differ!\n;"
}

$d->close();
exit;

#$d->init();
$password = "hGDlZpDDvDzqaetTpO";
$err = $d->Users->create($users[1], $password, int(rand(1000)));
if ($err) { print "Fail"; exit 1; } else { print "Ok"} print "\n";
$U = $d->Users->get($users[1]);
print "Name: " . $U->name . "\n" if $U;

if ($d->Users->check_password($U, $password)) {
	print "Password match!\n";
} else  {
	print "Password differ!\n;"
}

