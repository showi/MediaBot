#!/usr/bin/perl -W

use strict;
use warnings;

use Carp;

use lib qw(.);

use App::IRC::Bot::Shoze;
use App::IRC::Bot::Shoze::Log;

###########################################
# EDIT
###########################################

my $user = 'shoze';
my $group = 'sho';

my $BASE_PATH = "/srv/shoze/";
my $LOG_PATH = $BASE_PATH . "log/";

$App::IRC::Bot::Shoze::Debug = 9;


###########################################
# END OF EDIT
###########################################

#my $uid = (getpwnam($user))[2];
#die "Tentative de lancer le serveur en tant qu'utilisateur inexistant ou supperutilisateur\n" 
#    unless ($uid);
##chroot($BASE_PATH);
#$> = $uid;
 
$0 = "shozed";

my $SEP = '-'x80 . "\n";
my $DEMISEP = '-'x40 . "\n";
my $data_dir = $BASE_PATH . "data";
my $etc_dir = $BASE_PATH . "etc";
my $LOG_FILE = $LOG_PATH . "shoze.log";

my @dirs = ($BASE_PATH, $data_dir, $etc_dir, $LOG_PATH);
print $SEP;
print "- Checking directories\n";
print $DEMISEP;
for(@dirs) {
    print "$_\t";
    unless (-d $_) {
        print " Not found\n";
        die "Directory not found '$_'";
    }
    unless(-x $_) {
         print " Bad right (check permission)\n";
        die "Directory not found '$_'";
    }
    print "Ok\n";
}
my @files = (
    $LOG_FILE, 
    "$data_dir/mediabot.sqlite3",
    "$data_dir/server.crt",
    "$data_dir/server.key",
    "$etc_dir/bot.yaml",
    "$etc_dir/db.yaml",
    "$etc_dir/irc.yaml",
);
print $SEP;
print "- Checking files\n";
print $DEMISEP;
for(@files) {
    print "$_\t";
    unless (-e $_) {
        print " Not found\n";
        die "Directory not found '$_'";
    }
    unless(-r $_) {
         print " Bad right (check permission)\n";
        die "Directory not found '$_'";
    }
    print "Ok\n";
}
print $SEP;
$App::IRC::Bot::Shoze::Log::logfile = $LOG_FILE;

App::IRC::Bot::Shoze::Log::flush();
LOG("----- Starting Shoze -----");
LOG("Debug level: " . $App::IRC::Bot::Shoze::Debug)
    if $App::IRC::Bot::Shoze::Debug;
my $b = new App::IRC::Bot::Shoze($BASE_PATH);
$SIG{'INT'} = sub {print "\nBye!"; $b->POE->stop(); $b = undef; print "Bye\n";};
$b->POE->run();
LOG("----- Shoze ended -----");
exit(0);

1;
