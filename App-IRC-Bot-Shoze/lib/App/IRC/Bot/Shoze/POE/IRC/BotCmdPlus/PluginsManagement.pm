package App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::PluginsManagement;

use strict;
use warnings;
use Class::Unload;
use Class::Inspector;

use Carp;

use POE::Component::IRC::Plugin qw(:ALL);

use lib qw(../../../../../../../);
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
                help_description => 'reload plugin',
            },
            'plugin_load' => {
                access           => 'msg',
                lvl              => 800,
                help_cmd         => '!plugin.load <name>',
                help_description => 'load plugin',
            },
            'plugin_unload' => {
                access           => 'msg',
                lvl              => 800,
                help_cmd         => '!plugin.unload <name>',
                help_description => 'unload plugin',
            },
        }
    );
    my @plugins =
      qw(Users Info NetworkChannels NetworkChannelUsers NetworkChannelLogs ChannelUsers Help Tld EasySentence);
    $s->plugins( \@plugins );
    return $s;
}

sub PCI_register {
    my ( $s, $irc ) = splice @_, 0, 2;
    $s->irc($irc);
    my $C = $irc->plugin_get('BotCmdPlus');
    for my $cmd ( keys %{ $s->cmd } ) {
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

sub is_valid_plugin {
    my($s, $name) = @_;
    return 0 unless $name =~ /^\w+$/;    
}

sub _reload_plugin {
    my ( $s, $name ) = @_;
    my $err = 1;
    $err = 0 unless $s->_unload_plugin($name);
    $err = 0 unless $s->_load_plugin($name);
    return $err;
}

sub _load_plugin {
    my ( $s, $oname ) = @_;
    my $name   = $oname;
    my $plugin = "App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::$name";
    unless ( $s->loaded->{$oname} ) {
        LOG("LOAD: Requiring module '$plugin'");
        my $ret = eval "require $plugin";
        unless ( defined $ret ) {
            carp "Cannot require plugin '$plugin, abort loading! ($?)'";
            $s->irc->plugin_del("BotCmdPlus_$name");
            Class::Unload->unload($plugin);
            return 0;
        }
        $plugin->import();
        $s->loaded->{$oname} = 1;
        
        my $code;
        eval {
            local $SIG{'__DIE__'};
            $code=  $plugin->new($s);
        }; 
        if ($@) {
            $s->_unload_plugin($oname);
            WARN("Plugin Error: " . $@);
            return 0;
        }
        LOG("Plugin code for '$oname' loaded");
        $s->irc->plugin_add( "BotCmdPlus_$name", $code);
        return 1;
    }
    return 0;
}

sub _load_all_plugin {
    my ($s) = shift;
    for ( @{ $s->plugins } ) {
        $s->_load_plugin($_);
    }
}

sub _unload_plugin {
    my ( $s, $oname ) = @_;
    my $name   = $oname;
    my $plugin = "App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::$name";
    LOG("Removing plugin $plugin");
    $s->irc->plugin_del("BotCmdPlus_$name");
    Class::Unload->unload($plugin);
    delete $s->loaded->{$oname};

}

sub _unload_all_plugin {
    my ($s) = shift;
    for ( @{ $s->plugins } ) {
        $s->_unload_plugin($_);
    }
}

sub plugin_reload {
    my ( $s, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'plugin_reload';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = App::IRC::Bot::Shoze::Db->new;

    my ( $cmd, $name ) = split /\s+/, $msg;
    unless ( grep @{ $s->{plugins} }, $name ) {
        return $s->_n_error( $irc, $Session,
            "[$cmdname] Unknow command name!" );
    }
    if ( $s->_reload_plugin($name) ) {
        $irc->{Out}->notice('#me#', $Session, "Plugin $name reloaded" );
    }
    else {
        return $s->_n_error( $irc, $Session,
            "Cannot reload plugin '$name'" );
    }
    return PCI_EAT_ALL;
}

sub plugin_load {
    my ( $s, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'plugin_load';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = App::IRC::Bot::Shoze::Db->new;

    my ( $cmd, $name ) = split /\s+/, $msg;
    unless($s->is_valid_plugin($name)) {
        return $s->_n_error( $irc, $Session,
            "[$cmdname] Invalid plugin name!" );    
    }
    if ( defined $s->loaded->{$name} ) {
        return $s->_n_error( $irc, $Session,
            "[$cmdname] Plugin '$name' already loaded" );
    }
    if ( $s->_load_plugin($name) ) {
        $irc->{Out}->notice('#me#', $Session, "Plugin $name loaded" );
    }
    else {
        return $s->_n_error( $irc, $Session,
            "Cannot load plugin '$name'" );
    }
    return PCI_EAT_ALL;
}

sub plugin_unload {
    my ( $s, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'plugin_unload';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = App::IRC::Bot::Shoze::Db->new;

    my ( $cmd, $name ) = split /\s+/, $msg;
    unless ( grep @{ $s->{plugins} }, $name ) {
        return $s->_n_error( $irc, $Session,
            "[$cmdname] Unknow command name!" );
    }
    unless ( defined $s->loaded->{$name} ) {
        return $s->_n_error( $irc, $Session,
            "[$cmdname] Plugin '$name' is not loaded" );
    }
    if ( $s->_unload_plugin($name) ) {
        $irc->{Out}->notice('#me#', $Session, "Plugin $name unloaded" );
    }
    else {
        return $s->_n_error( $irc, $Session,
            "Cannot unload plugin '$name'" );
    }
    return PCI_EAT_ALL;
}

1;
