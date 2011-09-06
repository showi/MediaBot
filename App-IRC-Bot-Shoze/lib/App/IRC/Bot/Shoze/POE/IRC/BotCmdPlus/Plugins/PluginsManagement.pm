package App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::PluginsManagement;

use strict;
use warnings;

use Carp;

use POE::Component::IRC::Plugin qw(:ALL);

use lib qw(../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::String;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Helper qw(get_cmd);

use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::Info;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::User;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::Channel;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::ChannelEvent;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::Mode;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::Help;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::Mynick;

our %fields = ( cmd => undef, plugins => undef, irc => undef );

sub new {
    my ( $proto, $parent ) = @_;
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    $s->cmd(
        {
            'plugin_reload' => {
                access   => 'msg',
                lvl      => 800,
                help_cmd => '!user.add [user name] [password] <hostmask>',
                help_description => 'Adding user',
            },
        }
    );
    my @plugins = qw(mode info user channel help mynick channelEvent);
    $s->plugins( \@plugins );
    return $s;
}

sub PCI_register {
    my ( $s, $irc ) = splice @_, 0, 2;
    $s->irc($irc);
    my $C = $irc->plugin_get('BotCmdPlus');
    for my $cmd ( %{ $s->cmd } ) {
        $C->register_command(
            $s, $cmd,
            $s->cmd->{$cmd}->{access},
            $s->cmd->{$cmd}->{lvl}
        );
    }
    $s->_load_plugin();
    return 1;
}

sub PCI_unregister {
    my ( $s, $irc ) = splice @_, 0, 2;
    my $C = $irc->plugin_get('BotCmdPlus');
    for my $cmd ( %{ $s->cmd } ) {
        $C->unregister_command($cmd);
    }
    $s->_unload_plugin();
    return 1;
}

sub _load_plugin {
    my ($s) = shift;

    #LOG("PLUGINS: " . $s->plugins);
    for ( @{ $s->plugins } ) {
        my $name   = ucfirst( $_ );
        my $plugin = "App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::$name";
        LOG("Adding plugin $name");
        $s->irc->plugin_add( "BotCmdPlus_$name", $plugin->new );
    }
}

sub _unload_plugin {
    my ($s) = shift;
    for ( @{ $s->plugins } ) {
        my $name   = ucfirst( lc($_) );
        my $plugin = "App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::$name";
        LOG("Removing plugin $plugin");
        $s->irc->plugin_del("BotCmdPlus_$name");
    }
}

sub plugin_load {
    my ( $self, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'plugin_load';
    my $PCMD    = $self->get_cmd($cmdname);
    my $db      = $irc->{database};

    unless ( $Session->user_id ) {
        $irc->yield(
            notice => $Session->nick => "[$cmdname] You must be logged!" );
        return PCI_EAT_ALL;
    }
    if ( $User->lvl < $PCMD->{lvl} ) {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] You don't have the right to add channel!" );
        return PCI_EAT_ALL;
    }
    $self->_load_plugin;
    return PCI_EAT_ALL;
}

sub plugin_unload {
    my ( $self, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'plugin_unload';
    my $PCMD    = $self->get_cmd($cmdname);
    my $db      = $irc->{database};

    unless ( $Session->user_id ) {
        $irc->yield(
            notice => $Session->nick => "[$cmdname] You must be logged!" );
        return PCI_EAT_ALL;
    }
    if ( $User->lvl < $PCMD->{lvl} ) {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] You don't have the right to add channel!" );
        return PCI_EAT_ALL;
    }
    $self->_load_plugin;
    return PCI_EAT_ALL;
}

sub plugin_reload {
    my ( $self, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'plugin_reload';
    my $PCMD    = $self->get_cmd($cmdname);
    my $db      = $irc->{database};

    unless ( $Session->user_id ) {
        $irc->yield(
            notice => $Session->nick => "[$cmdname] You must be logged!" );
        return PCI_EAT_ALL;
    }
    if ( $User->lvl < $PCMD->{lvl} ) {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] You don't have the right to add channel!" );
        return PCI_EAT_ALL;
    }
    $self->_unload_plugin;
    $self->_load_plugin;
    return PCI_EAT_ALL;
}
1;
