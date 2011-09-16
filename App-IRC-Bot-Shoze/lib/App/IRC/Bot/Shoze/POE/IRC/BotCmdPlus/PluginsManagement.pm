package App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::PluginsManagement;

use strict;
use warnings;

use Carp;

use POE::Component::IRC::Plugin qw(:ALL);

use lib qw(../../../../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::String;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Helper qw(get_cmd _n_error);

our %fields = (
    _parent => undef,
    cmd     => undef,
    plugins => undef,
    irc     => undef,
    loaded  => undef
);

sub new {
    my ( $proto, $parent ) = @_;
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    $s->_parent($parent);
    $s->loaded( {} );
    $s->cmd(
        {
            'plugin_reload' => {
                access           => 'msg',
                lvl              => 800,
                help_cmd         => '!plugin.reload <name>',
                help_description => 'Adding user',
            },
        }
    );
    my @plugins =
      qw(networkChannelUsers);
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
    $s->_load_all_plugin();
    return 1;
}

sub PCI_unregister {
    my ( $s, $irc ) = splice @_, 0, 2;
    my $C = $irc->plugin_get('BotCmdPlus');
    for my $cmd ( %{ $s->cmd } ) {
        $C->unregister_command($cmd);
    }
    $s->_unload_all_plugin();
    return 1;
}

sub _reload_plugin {
    my ( $s, $name ) = @_;
    $s->_unload_plugin($name);
    $s->_load_plugin($name);
}

sub _load_plugin {
    my ( $s, $name ) = @_;
    $name = ucfirst($name);
    my $plugin = "App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::$name";
    unless ( $s->loaded->{$name} ) {
        LOG("LOAD: Requiring module '$plugin'");
        my $ret = eval "require $plugin";
        unless ( defined $ret ) {
            carp "Cannot require plugin '$plugin, abort loading! ($?)'";
            return 0;
        }
        $plugin->import();
        $s->loaded->{$name} = 1;
    }
    LOG("Adding plugin $name");
    $s->irc->plugin_add( "BotCmdPlus_$name", $plugin->new($s) );
    $s->loaded->{$name} = 1;
    return 1;
}

sub _load_all_plugin {
    my ($s) = shift;

    for ( @{ $s->plugins } ) {
        $s->_load_plugin($_);
    }
}

sub _unload_plugin {
    my ( $s, $name ) = @_;

    $name = ucfirst( lc($_) );
    my $plugin = "App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::$name";
    LOG("Removing plugin $plugin");
    $s->irc->plugin_del("BotCmdPlus_$name");
}

sub _unload_all_plugin {
    my ($s) = shift;
    for ( @{ $s->plugins } ) {
        $s->_unload_plugin($_);
    }
}

sub plugin_reload {
    my ( $s, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'plugin_reload';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = App::IRC::Bot::Shoze::Db->new;

    my ( $cmd, $name ) = split /\s+/, $msg;
    unless ( grep @{ $s->{plugins} }, $name ) {
        return $s->_n_error( $irc, Session->nick,
            "[$cmdname] Unknow command name!" );
    }
    $s->_reload_plugin($name);
    return PCI_EAT_ALL;
}

1;
