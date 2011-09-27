package App::IRC::Bot::Shoze::POE;

=head1 NAME

App::IRC::Bot::Shoze::POE - Aggregate our POE components

=cut

=head1 SYNOPSIS
    
This module aggregate our POE component (IRC, WebService)

=cut

use warnings;
use strict;

use Carp;
  BEGIN {
    package POE::Kernel;
    use constant ASSERT_DEFAULT => 1;
  }
  
use POE qw(
  Component
  Component::IRC
  Component::IRC::Plugin::AutoJoin
  Component::IRC::Plugin::CycleEmpty
  Component::IRC::Plugin::Connector
  Component::Server::TCP
  Filter::Stream
  Filter::SSL
);

use Data::Dumper;

use lib qw(../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::Constants;

use POE::Component::IRC::Plugin qw( :ALL );
use App::IRC::Bot::Shoze::POE::IRC;
use App::IRC::Bot::Shoze::POE::WS;
use App::IRC::Bot::Shoze::POE::SubTask;


our $AUTOLOAD;

my %fields = (
    _parent => undef,

    IRC     => undef,
    WS      => undef,
    SubTask => undef,
);

=head1 SUBROUTINES/METHODS

=over

=item new

=cut

sub new {
    my ( $proto, $parent ) = @_;
    DEBUG( "Creating new " . __PACKAGE__ );
    croak "No parent specified" unless ref $parent;
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    $s->_parent($parent);
   
    $s->IRC( new App::IRC::Bot::Shoze::POE::IRC($s));
    $s->SubTask( new App::IRC::Bot::Shoze::POE::SubTask($s) );
    $s->WS( new App::IRC::Bot::Shoze::POE::WS($s) );
    return $s;
}

=item run

=cut

sub run {
    LOG("[POE] starting\n");
    $poe_kernel->run();
}

=item stop

=cut

sub stop {
    LOG("[POE] starting\n");
    $poe_kernel->stop();
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
