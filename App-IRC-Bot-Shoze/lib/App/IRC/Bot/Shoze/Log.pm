package App::IRC::Bot::Shoze::Log;

use strict;
use warnings;

use Carp;
use Exporter;

our @ISA    = qw(Exporter);
our @EXPORT = qw(LOG DEBUG WARN);

our $logfile = "/var/log/shoze.log";

sub LOG {
    return unless $App::IRC::Bot::Shoze::DEBUG;
    my ( $msg, $type ) = @_;
    my $wh;
    my $logfile =  $App::IRC::Bot::Shoze::Log::logfile;
    open( $wh, ">>$logfile" )
      or die "Cannot open logfile $logfile";
    my $prefix = $type || "LOG";
    $msg = time . " [$prefix] $msg\n";
    if ( $prefix eq "LOG" ) {
        print $msg;
    }
    else {
        print STDERR $msg;
    }
    print $wh $msg;
}

sub DEBUG {
    return unless  $App::IRC::Bot::Shoze::DEBUG;
    if(defined $_[1]) {return if  $App::IRC::Bot::Shoze::DEBUG < $_[1]};
    my $prefix = "DEBUG";
    $prefix.="[".$_[1]."]" if defined $_[1];
    LOG( $_[0], $prefix );
}

sub WARN {
    return unless  $App::IRC::Bot::Shoze::DEBUG;
    if($_[1]) {return if  $App::IRC::Bot::Shoze::DEBUG < $_[1]};
    my $prefix = "WARN";
    $prefix.="[".$_[1]."]" if defined $_[1];
    LOG( $_[0], $prefix );
}

sub flush {
    return unless  $App::IRC::Bot::Shoze::DEBUG;
    my $wh;
    my $logfile =  $App::IRC::Bot::Shoze::Log::logfile;
    open( $wh, ">$logfile" )
      or die "Cannot open logfile $logfile";
    print $wh '-' x 80 . "\n";
}
1;
