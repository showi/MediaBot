package App::IRC::Bot::Shoze::Log;

=head1 NAME

App::IRC::Bot::Shoze::Log - Logging exported subroutines 

=cut

=head1 SYNOPSIS
    
This module export subroutines used by the bot for logging

=cut

use strict;
use warnings;

use Carp;
use Exporter;

=head1 EXPORT

=over

=item LOG

=item DEBUG

=item WARN

=back

=cut

our @ISA    = qw(Exporter);
our @EXPORT = qw(LOG DEBUG WARN);

our $logfile = "/var/log/shoze.log";

our $DEBUG = 5;

=head1 SUBROUTINES/METHODS

=over

=item LOG

=cut

sub LOG {
    return unless $DEBUG;
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

=item DEBUG

=cut

sub DEBUG {
    return unless  $DEBUG;
    if(defined $_[1]) {return if  $DEBUG < $_[1]};
    my $prefix = "DEBUG";
    $prefix.="[".$_[1]."]" if defined $_[1];
    LOG( $_[0], $prefix );
}

=item WARN

=cut

sub WARN {
    return unless  $DEBUG;
    if($_[1]) {return if  $DEBUG < $_[1]};
    my $prefix = "WARN";
    $prefix.="[".$_[1]."]" if defined $_[1];
    LOG( $_[0], $prefix );
}

=item flush

=cut

sub flush {
    return unless  $DEBUG;
    my $wh;
    my $logfile =  $App::IRC::Bot::Shoze::Log::logfile;
    open( $wh, ">$logfile" )
      or die "Cannot open logfile $logfile";
    print $wh '-' x 80 . "\n";
}

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2011 Joachim Basmaison.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;
