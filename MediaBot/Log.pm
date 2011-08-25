package MediaBot::Log;

use strict;
use warnings;

use Carp;
use Exporter;

our @ISA    = qw(Exporter);
our @EXPORT = qw(LOG DEBUG);

our $logfile = "log/mediabot.log";

sub LOG {
    my ( $msg, $type ) = @_;
    my $wh;
    my $logfile = $MediaBot::Log::logfile;
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
    return unless $MediaBot::DEBUG;
    LOG( $_[0], "DEBUG" );
}

sub flush {
    my $wh;
    my $logfile = $MediaBot::Log::logfile;
    open( $wh, ">$logfile" )
      or die "Cannot open logfile $logfile";
    print $wh '-' x 80 . "\n";
}
1;
