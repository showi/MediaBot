package App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::Tld;

=head1 NAME

App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::Tld - Tld plugin

=cut

=head1 SYNOPSIS

=cut

use strict;
use warnings;

use Carp;
use Encode qw(encode decode);
use Data::Dumper;
use YAML qw(Dump thaw);

use POE::Component::IRC::Plugin qw(:ALL);
use IRC::Utils qw(:ALL);

use lib qw(../../../../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::String;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Helper
  qw(_register_cmd _unregister_cmd get_cmd _n_error);
use App::IRC::Bot::Shoze::POE::SubTask::Request;

our %fields = ( cmd => undef, _parent => undef );

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
    my $program = $s->_get_root->_path . "/scripts/tld.pl";
    unless ( -x $program ) {
        die "Error: $program not found or not executable";
    }
    $s->cmd(
        {
            'tld' => {
                access           => 'public',
                lvl              => 0,
                help_cmd         => '!tld <tld>',
                help_description => 'Give ue tld',
            },
        }
    );
    return $s;
}

=item PCI_register

=cut

sub PCI_register {
    my ( $s, $irc ) = splice @_, 0, 2;
    $irc->plugin_register( $s, 'SERVER', qw(tld_result) );
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

=item S_tld_result

=cut

sub S_tld_result {
    my ( $s, $irc ) = splice @_, 0, 2;
    my ( $who, $where, $result ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my ( $nick, $user, $hostmask ) = parse_user($who);
    print Dump $result;
    my $ref = thaw( $result->data );
    if ( $result->status < 0 ) {
        $s->_n_error( $irc, $where,
            "Error: Script is missing or not executable" );
    }
    my $d = $ref;
    if ( $result->status ) {
        $irc->privmsg('#me#', $where, "Error: no match for tld "
              . $d->{tld_ascii} . " ("
              . $d->{tld_origin} . "), "
              . $d->{type} );
        return PCI_EAT_ALL;
    }

    my $str = $d->{tld_ascii} . " (" . $d->{tld_origin} . "), " . $d->{type};
    $str .= ": " . $d->{info} if $d->{info};
    $irc->privmsg('#me#', $where, $str );
    return PCI_EAT_ALL;
}

=item tld

=cut

sub tld {
    my ( $s, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'tld';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = App::IRC::Bot::Shoze::Db->new;

    my ( $nick, $user, $hostmask ) = parse_user($who);
    my $cmd;
    ( $cmd, $msg ) = split( /\s+/, str_chomp($msg) );
    my $request = new App::IRC::Bot::Shoze::POE::SubTask::Request;
    $request->event('irc_tld_result');
    $request->name('tld');
    $request->program( $s->_get_root->_path . "/scripts/tld.pl" );
    $request->args($msg);
    $request->who($where);
    $request->where( $where->[0] );
    $request->session_id($irc->session_id);
    my $SubTask = App::IRC::Bot::Shoze->new->POE->SubTask;
    $SubTask->add_task($request);
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
