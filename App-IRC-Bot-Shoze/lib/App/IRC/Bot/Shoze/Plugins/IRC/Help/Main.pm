package App::IRC::Bot::Shoze::Plugins::IRC::Help::Main;

=head1 NAME

App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::Help - Help plugin

=cut

=head1 SYNOPSIS

=cut

use strict;
use warnings;

use Carp;

use POE::Component::IRC::Plugin qw(:ALL);

use Data::Dumper;

use lib qw(../../../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::String;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Helper qw(:ALL);

our $VERSION           = '0.0.1';
our $MAINCOMPATIBILITY = '0.0.8';

our %fields = ( cmd => undef );

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
    $s->cmd(
        {
            'help' => {
                access           => 'msg',
                lvl              => 0,
                help_cmd         => '!help [regexp]',
                help_description => 'Listing available command',
            },
        }
    );
    return $s;
}

=item help

=cut

sub help {
    my ( $self, $Session,  $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'help';
    my $PCMD    = $self->get_cmd($cmdname);
    my $C       = $irc->plugin_get('IRC_Core_BotCmdPlus');
    my $mylvl   = 0;
    my $lh      = $Session->_lh;
    
    my ($cmd, $match) = split(/\s+/, $msg);
    if ($match =~ /^[\w\d]+$/) {
        $match = qr/$match/;  
    }else {
      $match = undef;
    }
    $mylvl = $Session->user_lvl if ($Session->user_id);
    $irc->{Out}->respond_user($Session, "[$cmdname] " . $lh->maketext('Listing commands for level [_1]', $Session->user_lvl) );
    
    for my $cmd ( sort keys %{ $C->cmd } ) {
        if ($match) {
            next unless $cmd =~ /$match/i;
        }
        my $plugin = $C->cmd->{$cmd}->{plugin}->cmd->{$cmd};

        next if $mylvl < $plugin->{lvl};
        $irc->{Out}->respond_user($Session, " " . $plugin->{help_cmd});
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
