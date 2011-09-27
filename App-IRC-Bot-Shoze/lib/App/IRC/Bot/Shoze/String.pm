package App::IRC::Bot::Shoze::String;

=head1 NAME

App::IRC::Bot::Shoze::String - Strings helper

=cut

=head1 SYNOPSIS
    
String utilities

=head1 TODO

Don't export all subroutines by default

=cut

use strict;
use warnings;

use Carp;
use Exporter;

use lib qw(../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY);

=head1 EXPORT

=over

=item str_chomp

=item esc_ascii

=item esc_nick

=item esc_ident

=item esc_host

=item esc_password

=item esc_str_fixsize


=back

=cut

our @ISA    = qw(Exporter);
our @EXPORT = qw(str_chomp esc_ascii esc_nick esc_ident esc_host esc_password str_fixsize);
our $AUTOLOAD;

=head1 SUBROUTINES/METHODS

=over

=item str_chomp

=cut

sub str_chomp {
    my $str = $_[0];
    return undef unless defined $str;
    return "" unless $str;
    $str =~ s/^\s+//;    #remove leading spaces
    $str =~ s/\s+$//;    #remove trailing spaces
    return $str;
}

=item esc_host

=cut

sub esc_host {
   my $str = str_chomp($_[0]);
   $str =~ s/[^a-z0-9\._-]//gi;
    return $str;    
}

=item esc_nick

=cut

sub esc_nick {
   my $str = str_chomp($_[0]);
   print "nick: $str\n";
   $str =~ s/[^a-z0-9\[\]_-]//gi;
   return $str;    
}

=item str_ident

=cut

sub esc_ident {
   my $str = str_chomp($_[0]);
   $str =~ s/[^a-z0-9~_-]//gi;
   return $str;    
}

sub esc_password {
   my $str = str_chomp($_[0]);
   $str =~ s/[^a-z0-9_-]//gi;
   return $str;    
}

=item str_fixsize

=cut

sub str_fixsize {
    my $str = str_chomp($_[0]);
    #my $size = $_[1];
    my $len = length $str;
    if ($len > $_[1]) {
        return substr($str, 0, $_[1]);
    } else {
        $str.= ' 'x ($_[1] - $len);
        return $str;
    } 
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
