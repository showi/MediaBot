package App::IRC::Bot::Shoze::Plugins::IRC::Icecast::Main;

=head1 NAME

App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::Icecast - Icecast plugin

=cut

=head1 SYNOPSIS

=cut

use strict;
use warnings;

use Carp;
use Encode qw(encode decode);
use Data::Dumper;
use YAML qw(Dump thaw);
use Cache::FileCache;

use POE::Component::IRC::Plugin qw(:ALL);
use IRC::Utils qw(:ALL);

use lib qw(../../../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::String;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Helper
  qw(_register_cmd _unregister_cmd get_cmd _n_error);
use App::IRC::Bot::Shoze::POE::SubTask::Request;

our %fields = ( cmd => undef, _parent => undef, cache_hint => undef );

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
    $s->cache_hint('plugin_icecast');
    my $program = $s->_get_root->_path . "/scripts/icestats.pl";
    unless ( -x $program ) {
        die "Error: $program not found or not executable";
    }
    $s->cmd(
             {
               'listeners' => {
                              access           => 'public|msg',
                              lvl              => 0,
                              help_cmd         => '!listeners <tld>',
                              help_description => 'Give radiocapsule listeners',
               },
               'auditeurs' => {
                              access           => 'public|msg',
                              lvl              => 0,
                              help_cmd         => '!listeners <tld>',
                              help_description => 'Give radiocapsule listeners',
               },
             }
    );
    return $s;
}

=item PCI_register

=cut

sub PCI_register {
    my ( $s, $irc ) = splice @_, 0, 2;
    $irc->plugin_register( $s, 'SERVER', qw(icecast_listeners_result) );
    $s->_register_cmd($irc);
    return 1;
}

=item PCI_unregister

=cut

sub PCI_unregister {
    my ( $s, $irc ) = splice @_, 0, 2;
    $s->_unregister_cmd($irc);
    return 1;
}

=item S_icecast_listeners_result

=cut

sub S_icecast_listeners_result {
    my ( $s, $irc ) = splice @_, 0, 2;
    my ( $who, $where, $result ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my ( $nick, $user, $hostmask ) = parse_user($who);

    my $cache = new Cache::FileCache();
    unless ( $result->status ) {
        $cache->set( $s->cache_hint, $result, "1 minutes" );
    } else {
        $cache->remove($s->cache_hint);
    }
    my $target = $where;
    if ( $result->input_event eq 'S_msg' ) {
        my ( $nick, $user, $hostmask ) = parse_user($who);
        $target = $nick;
    }

    if ( $result->status < 0 ) {
        my $msg = "";
        $msg = $result->status_msg if $result->status_msg;
        $s->_n_error( $irc, $target, "Error: Cannot get listeners '$msg'" );
    }

    my $ref = $result->data;
    my $d   = $ref->{icestats};
    if ( $result->status ) {
        $irc->{Out}
          ->privmsg( '#me#', $target, "Error: Can't fetch listeners!" );
        return PCI_EAT_ALL;
    }

    my $str = $d->{host} . " / " . $d->{listeners} . " listeners";
    $irc->{Out}->privmsg( '#me#', $target, $str );
    return PCI_EAT_ALL;
}

=item listeners

=cut

sub listeners {
    my ( $s, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'listeners';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = App::IRC::Bot::Shoze::Db->new;

    my ( $nick, $user, $hostmask ) = parse_user($who);
    my $cmd;
    ( $cmd, $msg ) = split( /\s+/, str_chomp($msg) );

    my $cache  = new Cache::FileCache();
    my $result = $cache->get($s->cache_hint);
    if ( defined $result ) {
        LOG("Result from cache");
        $irc->send_event( $result->event, $result->who,
                          $result->where, $result );
        return PCI_EAT_ALL;
    }
    my $request = new App::IRC::Bot::Shoze::POE::SubTask::Request;
    $request->input_event($event);
    $request->event('irc_icecast_listeners_result');
    $request->name('icecast');
    $request->program( $s->_get_root->_path . "/scripts/icestats.pl" );
    $request->who($who);
    $request->where( $where->[0] );
    $request->session_id( $irc->session_id );
    my $SubTask = App::IRC::Bot::Shoze->new->POE->SubTask;
    $SubTask->add_task($request);
    return PCI_EAT_ALL;
}

=item auditeurs

=cut

sub auditeurs {
    my ($s) = shift;
    return $s->listeners(@_);
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
