package App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Helper;

use strict;
use warnings;

use Carp;
use Exporter;

use POE::Component::IRC::Plugin qw(:ALL);

use lib qw(../../../../);
use App::IRC::Bot::Shoze::Log;

our @ISA = qw(Exporter);

our @MyExport = qw(_n_error _send_lines
  pretty_help get_cmd
  PCI_register PCI_unregister
  _register_cmd _unregister_cmd
  BOTLVL CHANLVL);

our @EXPORT_OK = @MyExport;
our @EXPORT    = @MyExport;

sub pretty_help {
    my ( $s, $cmd ) = @_;
    croak "Invalid command '$cmd'" unless defined $s->{cmd}->{$cmd};
    return $s->{cmd}->{$cmd}->{help_cmd} . "\n"
      . $s->{cmd}->{$cmd}->{help_description};
}

sub get_cmd {
    my ( $s, $cmd ) = @_;
    croak "Invalid command '$cmd'" unless defined $s->{cmd}->{$cmd};
    return $s->cmd->{$cmd};
}

sub _register_cmd {
    my ( $s, $irc ) = @_;
    my $C = $irc->plugin_get('BotCmdPlus');
    for my $cmd ( %{ $s->cmd } ) {
        $C->register_command(
            $s, $cmd,
            $s->cmd->{$cmd}->{access},
            $s->cmd->{$cmd}->{lvl}
        );
    }
}

sub PCI_register {
    my ( $s, $irc ) = splice @_, 0, 2;
    $s->_register_cmd($irc);
    return 1;
}

sub _unregister_cmd {
    my ( $s, $irc ) = @_;
    my $C = $irc->plugin_get('BotCmdPlus');
    for my $cmd ( %{ $s->cmd } ) {
        $C->unregister_command($cmd);
    }
}

sub PCI_unregister {
    my ( $s, $irc ) = splice @_, 0, 2;
    $s->_unregister_cmd($irc);
    return 1;
}

sub _send_lines {
    my ( $s, $irc, $what, $where, @lines ) = @_;
    for (@lines) {
        $irc->yield( $what => $where => $_ );
    }
}

sub _n_error {
    my ( $s, $irc, $who, $msg ) = @_;
    $irc->yield( "notice" => $who => "Error: $msg" );
    return PCI_EAT_ALL;
}

sub BOTLVL {
    my $lvl = shift;
    return "owner    " if $lvl >= 1000;
    return "admin    " if $lvl >= 800;
    return "chanowner" if $lvl >= 500;
    return "user     ";
}

sub CHANLVL {
    my $lvl = shift;
    return "owner" if $lvl >= 500;
    return "admin" if $lvl >= 400;
    return "user " if $lvl >= 200;
}

1;
