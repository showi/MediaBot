package App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus;

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

sub PCI_register {
    my ( $s, $irc ) = splice @_, 0, 2;
    $s->cmd( {} );
    $irc->plugin_add( 'BotCmdPlus_Sessions',
        new App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Sessions($s) );

    $irc->plugin_add( 'BotCmdPlus_Dispatch',
        new App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Dispatch($s) );
   
    return 1;
}

sub PCI_unregister {
    my ( $s, $irc ) = splice @_, 0, 2;
    $irc->plugin_del( 'BotCmdPlus_Sessions',
        new App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Sessions($s) );

    $irc->plugin_del( 'BotCmdPlus_Dispatch',
        new App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Dispatch($s) );
    delete $s->{cmd};
    return 1;
}

sub get_cmd {
    my ( $s, $cmd ) = @_;
    return $s->cmd->{$cmd} if defined $s->cmd->{$cmd};
}

sub register_command {
    my ( $s, $plugin, $cmd, $acces, $lvl ) = @_;
    return
      if ref($cmd)
    ;    ### Dirty hack, something's going wrong on plugin registration###
    DEBUG( "Registering command $cmd with access level $lvl ($plugin)", 2 );
    croak "Cannot register command '$cmd'"
      if defined $s->cmd->{$cmd};
    $s->cmd->{$cmd} = {
        plugin => $plugin,
        lvl    => $lvl,
        access => $acces,
    };
}

sub unregister_command {
    my ( $s, $cmd ) = @_;
    DEBUG( "Unregistering command $cmd", 2 );
    delete $s->cmd->{$cmd} if $s->cmd->{$cmd};
}

1;
