package MediaBot::String;

use strict;
use warnings;

use Carp;
use Exporter;

use lib qw(..);
use MediaBot::Class qw(AUTOLOAD DESTROY LOG);

our @ISA = qw(Exporter);
our @EXPORT = qw(str_chomp str_asciionly);
our $AUTOLOAD;


sub str_chomp {
	my $str = $_[0];
	$str =~ s/^\s+//; #remove leading spaces
	$str =~ s/\s+$//; #remove trailing spaces	
	return $str;
}

sub str_asciionly {
	my $str = $_[0];
	$str =~ s/[^a-z0-9~\._-]//gi;
	return $str;
}

1;