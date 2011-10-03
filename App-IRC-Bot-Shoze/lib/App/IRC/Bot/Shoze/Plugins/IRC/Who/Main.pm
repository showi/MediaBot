package App::IRC::Bot::Shoze::Plugins::IRC::Who::Main;

=head1 NAME

App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::Who - Who plugin

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
           'whoami' => {
               access           => 'msg',
               lvl              => 200,
               help_cmd         => '!whoami',
               help_description => 'Display current username',

               #rgument_filter  => qr/^.*$/,
           },
           'who' => {
               access           => 'msg',
               lvl              => 200,
               help_cmd         => '!tld <tld>',
               help_description => 'Display logged user',

               #rgument_filter  => qr/^.*$/,
           },
        }
    );
    return $s;
}

=item PCI_register

=cut

sub PCI_register {
    my ( $s, $irc ) = splice @_, 0, 2;

    #$irc->plugin_register( $s, 'SERVER', qw(tld_result) );
    #$s->_register_database($irc);
    $s->_register_cmd($irc);
    return 1;
}

=item PCI_unregister

=cut

sub PCI_unregister {
    my ( $s, $irc ) = splice @_, 0, 2;
    $s->_unregister_cmd($irc);

    #$s->_unregister_database($irc);
    return 1;
}

=item whoami

=cut

sub whoami {
    my ( $s, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'whoami';
    my $PCMD    = $s->get_cmd($cmdname);

    $irc->{Out}->notice(
                         '#me#',
                         $Session,
                         "User: "
                           . $Session->user_name . " / "
                           . $Session->user_lvl . " / "
                           . $Session->user_hostmask
    );
    return PCI_EAT_ALL;
}

=item who

=cut

sub who {
    my ( $s, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'whoami';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = App::IRC::Bot::Shoze::Db->new;

    my @UL = $db->NetworkSessions->list_by( $irc->{Network},
                                            { user_id => "#NOTNULL#" } );
    for (@UL) {
        $irc->{Out}->notice(
            '#me#',
            $Session,
            "User: "
              . $_->user_name . " / "
              . $_->user_lvl . " / ( "
              . $_->nick . ' / ' . localtime($_->updated_on) . ')'

        );
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
