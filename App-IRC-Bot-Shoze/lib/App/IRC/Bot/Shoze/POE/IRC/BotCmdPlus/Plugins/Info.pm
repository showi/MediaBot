package App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::Info;

=head1 NAME

App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::Info - Info plugin

=cut

=head1 SYNOPSIS

=cut

use strict;
use warnings;

use Carp;

use POE;
use POE::Component::IRC::Plugin qw(:ALL);

use lib qw(../../../../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::String;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Helper qw(:ALL);

use Data::Dumper;

our %fields = ( cmd => undef, );

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
            'version' => {
                access           => 'msg|public',
                lvl              => 0,
                help_cmd         => '!version',
                help_description => 'Who am i!',
            },
        }
    );
    return $s;
}

=item version

=cut

sub version {
    my ( $self, $Session,  $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'version';
    my $PCMD    = $self->get_cmd($cmdname);

    my $nick    = $Session->nick;
    my $channel = $where->[0];
    no warnings;
    my $version =
"I'm running $App::IRC::Bot::Shoze::PROGRAMNAME($App::IRC::Bot::Shoze::VERSIONNAME/$App::IRC::Bot::Shoze::VERSION)";
    use warnings;
    $where = $nick;
    if ( $event =~ /^\w_public$/ ) {
        $where = $channel;
    }
    $irc->{Out}->privmsg('#me#', $where,  $version );
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
