package App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus;

=head1 NAME

App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus - Bot plugins system 

=cut

=head1 SYNOPSIS

=cut

use strict;
use warnings;

use Carp;
use POE;
use POE::Component::IRC::Plugin qw(:ALL);

use lib qw(../../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY);
use App::IRC::Bot::Shoze::Constants;
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Sessions;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Dispatch;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::PluginsManagement;

use Data::Dumper qw(Dumper);

our %fields = ( cmd => undef, );

=head1 SUBROUTINES/METHODS

=over

=item new

=cut

sub new {
    my ($proto) = @_;
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    $s->cmd( {} );
    return $s;
}

=item PCI_register

=cut

sub PCI_register {
    my ( $s, $irc ) = splice @_, 0, 2;
    $s->cmd( {} );
    $irc->plugin_add( 'BotCmdPlus_Sessions',
        new App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Sessions($s) );

    $irc->plugin_add( 'BotCmdPlus_Dispatch',
        new App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Dispatch($s) );

    return 1;
}

=item PCI_unregister

=cut

sub PCI_unregister {
    my ( $s, $irc ) = splice @_, 0, 2;
    $irc->plugin_del( 'BotCmdPlus_Sessions',
        new App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Sessions($s) );

    $irc->plugin_del( 'BotCmdPlus_Dispatch',
        new App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Dispatch($s) );
    delete $s->{cmd};
    return 1;
}

=item get_cmd

=cut

sub get_cmd {
    my ( $s, $cmd ) = @_;
    return $s->cmd->{$cmd} if defined $s->cmd->{$cmd};
}

=item register_command

=cut

sub register_command {
    my ( $s, $plugin, $cmd, $access, $lvl ) = @_;
    return if ref($cmd);
    DEBUG( "Registering command $cmd with access level $lvl ($plugin)", 5 );
    croak "Cannot register command '$cmd'"
      if defined $s->cmd->{$cmd};
    $s->cmd->{$cmd} = {
        plugin => $plugin,
        lvl    => $lvl,
        access => $access,
    };
}

=item unregister_command

=cut

sub unregister_command {
    my ( $s, $cmd ) = @_;
    DEBUG( "Unregistering command $cmd", 2 );
    delete $s->cmd->{$cmd} if $s->cmd->{$cmd};
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
