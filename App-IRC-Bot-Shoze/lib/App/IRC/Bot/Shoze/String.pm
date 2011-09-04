package App::IRC::Bot::Shoze::String;

use strict;
use warnings;

use Carp;
use Exporter;

use lib qw(..);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY);

our @ISA    = qw(Exporter);
our @EXPORT = qw(str_chomp esc_ascii esc_nick esc_ident esc_host esc_password str_fixsize);
our $AUTOLOAD;

sub str_chomp {
    my $str = $_[0];
    $str =~ s/^\s+//;    #remove leading spaces
    $str =~ s/\s+$//;    #remove trailing spaces
    return $str;
}

sub esc_host {
   my $str = str_chomp($_[0]);
   $str =~ s/[^a-z0-9\._-]//gi;
    return $str;    
}

sub esc_nick {
   my $str = str_chomp($_[0]);
   print "nick: $str\n";
   $str =~ s/[^a-z0-9\[\]_-]//gi;
   return $str;    
}

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
1;
