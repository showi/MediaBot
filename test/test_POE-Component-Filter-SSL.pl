#!/usr/bin/perl

use warnings;
use strict;

use POE qw(Component::Server::TCP);

POE::Component::Server::TCP->new(
    Port => 9090,
    ClientFilter =>
      [ "POE::Filter::SSL", crt => 'server.crt', key => 'server.key' ],
    ClientConnected => sub {
        print "got a connection from $_[HEAP]{remote_ip}\n";
        $_[HEAP]{client}->put("Smile from the server!");
    },
    ClientInput => sub {
        my $client_input = $_[ARG0];

        # The following line is needed to do the SSL handshake!
        return $_[HEAP]{client}->put() unless $client_input;
        $client_input =~ tr[a-zA-Z][n-za-mN-ZA-M];
        $_[HEAP]{client}->put($client_input);
    },
);

POE::Kernel->run;
exit;
