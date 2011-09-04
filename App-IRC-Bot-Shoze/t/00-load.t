#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'App::IRC::Bot::Shoze' ) || print "Bail out!\n";
}

diag( "Testing App::IRC::Bot::Shoze $App::IRC::Bot::Shoze::VERSION, Perl $], $^X" );
