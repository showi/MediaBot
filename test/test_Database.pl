#!/usr/bin/perl

use strict;
use warnings;

use lib qw(../App-IRC-Bot-Shoze/lib/);

use App::IRC::Bot::Shoze::Config;
use App::IRC::Bot::Shoze::Db;

use App::IRC::Bot::Shoze::Db::NetworkNicks::Object;

my $C = new App::IRC::Bot::Shoze::Config('/srv/shoze/');

my $D = new App::IRC::Bot::Shoze::Db();

my $Network = $D->Networks->get_by({name => 'nosferat.us' });
print $Network->_pretty;

my @nicks = qw(gilo boulo derek sophia karmin);
for(@nicks) {
    my $Nick = $D->NetworkNicks->get_by($Network, {nick => $_});
    if ($Nick) {
        print "Nick already present for network " . $Network->name . "\n";
        print $Nick->_pretty;
        next;
    }
    my $r = $D->NetworkNicks->create($Network, $_);
    unless($r) {
        print "Cannot create nick $_ for network " . $Network->name . "\n";
    }
    $Nick = $D->NetworkNicks->get_by($Network, {nick => $_, network_id => $Network->id});
    print $Nick->_pretty;
}

my @channels = ('#root', '#sunshine', '#nation', '#one');
for(@channels) {
    my ($type, $name) = (/^(#|&)(.*)$/);
    my $Channel = $D->NetworkChannels->get_by($Network, { type => $type, name => $name});
    unless($Channel) {
        my $r = $D->NetworkChannels->create($Network, $type, $name, undef);
        unless($r) {
            print "Cannot create channel $_ for network " . $Network->name . "\n";
            next;
        }
       $Channel = $D->NetworkChannels->get_by($Network, {type => $type, name => $name});

    }
    print $Channel->_pretty;
}

for my $channel(@channels) {
    for my $nick(@nicks) {
        my ($type, $name) = ($channel =~ /^(#|&)(.*)$/);
        my $Channel = $D->NetworkChannels->get_by($Network, {type => $type, name => $name});
        my $Nick = $D->NetworkNicks->get_by($Network, {nick => $nick});
        print $Nick->_pretty;
        next unless $Nick;
        next unless $Channel;
        my $ncu = $D->NetworkChannelUsers->get_by($Channel, {nick_id => $Nick->id});
        next if $ncu;
        $ncu = $D->NetworkChannelUsers->create($Channel, $Nick);     
    }
}

$D->NetworkNicks->empty($Network);

1;