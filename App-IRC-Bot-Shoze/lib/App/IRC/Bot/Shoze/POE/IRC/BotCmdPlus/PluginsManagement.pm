package App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::PluginsManagement;

=head1 NAME

App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::PluginsManagement - PLugins management

=cut

=head1 SYNOPSIS
    
This module permit to load/unload plugin even while the bot is running

=cut

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
    core_plugins => undef,
    irc     => undef,
    loaded  => undef
);

=head1 SUBROUTINES/METHODS

=over

=item new

=cut

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
    my @core_plugins = qw(Sessions Dispatch PluginsManagement);
    $s->core_plugins( \@core_plugins );
    my $C = App::IRC::Bot::Shoze::Config->new;
    my @plugins = split(/\s+/, $C->bot->{plugins});
    $s->plugins( \@plugins );
    return $s;
}

=item PCI_register

=cut

sub PCI_register {
    my ( $s, $irc ) = splice @_, 0, 2;
    $s->irc($irc);
    my $C = $irc->plugin_get('BotCmdPlus');
    for my $cmd ( keys %{ $s->cmd } ) {
        $C->register_command(
            $s, $cmd,
            $s->cmd->{$cmd}->{access},
            $s->cmd->{$cmd}->{lvl},
            $s->cmd->{$cmd}->{argument_filter}
        );
    }
    $s->_load_all_plugin();
    return 1;
}


=item PCI_unregister

=cut

sub PCI_unregister {
    my ( $s, $irc ) = splice @_, 0, 2;
    my $C = $irc->plugin_get('BotCmdPlus');
    for my $cmd ( %{ $s->cmd } ) {
        $C->unregister_command($cmd);
    }
    $s->_unload_all_plugin();
    return 1;
}


=item is_valid_plugin

=cut

sub is_valid_plugin {
    my($s, $name) = @_;
    return 0 unless $name =~ /^\w+$/;    
}


=item _reload_plugin

=cut

sub _reload_plugin {
    my ( $s, $name ) = @_;
    my $err = 1;
    $err = 0 unless $s->_unload_plugin($name);
    $err = 0 unless $s->_load_plugin($name);
    return $err;
}


=item _load_plugin

=cut

sub _load_plugin {
    my ( $s, $oname ) = @_;
    my $name   = $oname;
    my $plugin = 'App::IRC::Bot::Shoze::Plugins::IRC::'.$name.'::Main';
    unless ( $s->loaded->{$oname} ) {
        LOG("LOAD: Requiring module '$plugin'");
        my $ret = eval "require $plugin";
        unless ( defined $ret ) {
            carp "Cannot require plugin '$plugin, abort loading! ($?)'";
            $s->irc->plugin_del("Plugin_IRC_$name");
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
            WARN("Plugin Error: " . $@);
            $s->_unload_plugin($oname);
            return 0;
        }
        LOG("Plugin code for '$oname' loaded");
        $s->irc->plugin_add( "Plugin_IRC_$name", $code);
        return 1;
    }
    return 0;
}


=item _load_all_plugin

=cut

sub _load_all_plugin {
    my ($s) = shift;
    for ( @{ $s->plugins } ) {
        $s->_load_plugin($_);
    }
}


=item _unload_plugin

=cut

sub _unload_plugin {
    my ( $s, $oname ) = @_;
    my $name   = $oname;
    my $plugin = 'App::IRC::Bot::Shoze::Plugins::IRC::'.$name.'::Main';
    LOG("Removing plugin $plugin");
    $s->irc->plugin_del("Plugin_IRC_$name");
    Class::Unload->unload($plugin);
    delete $s->loaded->{$oname};

}

=item _unload_all_plugin

=cut

sub _unload_all_plugin {
    my ($s) = shift;
    for ( @{ $s->plugins } ) {
        $s->_unload_plugin($_);
    }
}


=item plugin_reload

=cut

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


=item plugin_load

=cut

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


=item plugin_unload

=cut

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

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2011 Joachim Basmaison.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;
