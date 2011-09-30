package App::IRC::Bot::Shoze::Plugins::IRC::Tld::Main;

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

use lib qw(../../../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::String;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Helper
  qw(_register_cmd _unregister_cmd _register_database _unregister_database get_cmd _n_error);
use App::IRC::Bot::Shoze::POE::SubTask::Request;

our %fields = ( cmd => undef, _parent => undef, database => undef );

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
               access           => 'public|msg',
               lvl              => 0,
               help_cmd         => '!tld <tld>',
               help_description => 'Give ue tld',

               #rgument_filter  => qr/^.*$/,
           },
        }
    );
    my @db;
    push @db,
      {
        type => 'IRC',
        name => 'Tld',
      };
    $s->database( \@db );
    return $s;
}

=item PCI_register

=cut

sub PCI_register {
    my ( $s, $irc ) = splice @_, 0, 2;
    $irc->plugin_register( $s, 'SERVER', qw(tld_result) );
    $s->_register_database($irc);
    $s->_register_cmd($irc);
    return 1;
}

=item PCI_unregister

=cut

sub PCI_unregister {
    my ( $s, $irc ) = splice @_, 0, 2;
    $s->_unregister_cmd($irc);
    $s->_unregister_database($irc);
    return 1;
}

=item S_tld_result

=cut

sub S_tld_result {
    my ( $s, $irc ) = splice @_, 0, 2;
    my ( $who, $where, $result ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my ( $nick, $user, $hostmask ) = parse_user($who);
    my $db      = App::IRC::Bot::Shoze::Db->new;

    if ( $result->status < 0 ) {
        $s->_n_error( $irc, $where,
                      "Error: Script is missing or not executable" );
    }
    print Dump $result;
    my $ref    = $result->data;
    my $target = $where;
    if ( $result->input_event eq 'S_msg' ) {
        my ( $nick, $user, $hostmask ) = parse_user($who);
        $target = $nick;
    }
    my $d = $ref;
    if ( $result->status ) {
        $irc->{Out}->privmsg(
                              '#me#',
                              $target,
                              "Error: no match for tld "
                                . $d->{tld_ascii} . " ("
                                . $d->{tld_origin} . "), "
                                . $d->{type}
        );
        return PCI_EAT_ALL;
    }
    unless (my $Tld = $db->Plugins->Tld->get_by({ utf8 => $d->{tld_origin} }) ) {
        $Tld = App::IRC::Bot::Shoze::Plugins::IRC::Tld::Db::Object->new($db);
        $Tld->ascii($d->{tld_ascii});
        $Tld->utf8($d->{tld_origin});
        $Tld->type($d->{type});
        $Tld->info($d->{info}) if $d->{info};
        $Tld->_create();
    }
    my $str = $d->{tld_ascii} . " (" . $d->{tld_origin} . "), " . $d->{type};
    $str .= ": " . $d->{info} if $d->{info};
    $irc->{Out}->privmsg( '#me#', $target, $str );
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
    unless ($msg) {
        $irc->{Out}
          ->notice( '#me#', $Session, "Error: !tld <top level domain string>" );
        return PCI_EAT_ALL;
    }
    my $request = new App::IRC::Bot::Shoze::POE::SubTask::Request;
    $request->input_event($event);
    $request->event('irc_tld_result');
    $request->name('tld');
    $request->program( $s->_get_root->_path . "/scripts/tld.pl" );
    $request->args($msg);
    $request->who($who);
    $request->where( $where->[0] );
    $request->session_id( $irc->session_id );
    if (my $Tld = $db->Plugins->Tld->get_by({utf8 => $msg})) {
        my %rh = (
            tld_ascii => $Tld->ascii,
            tld_origin => $Tld->utf8,
            type => $Tld->type, 
        );
        $rh{info} = $Tld->info if $Tld->info;
        $request->data(\%rh);
        $request->status(0);
        $irc->send_event($request->event, $request->who, $request->where, $request);
        print "Got result from db\n";
        return PCI_EAT_ALL;
    }
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
