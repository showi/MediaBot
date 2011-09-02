package MediaBot::IRC::BotCmdPlus::Plugins::Help;

use strict;
use warnings;

use Carp;

use POE::Component::IRC::Plugin qw(:ALL);

use Data::Dumper;

use lib qw(../../../../);
use MediaBot::Class qw(AUTOLOAD DESTROY);
use MediaBot::Log;
use MediaBot::String;
use MediaBot::IRC::BotCmdPlus::Helper;

our %fields = ( cmd => undef );

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
                help_cmd         => '!help',
                help_description => 'Listing available command',
            },
        }
    );
    return $s;
}

sub help {
    my ( $self, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'help';
    my $PCMD    = $self->get_cmd($cmdname);
    my $C       = $irc->plugin_get('BotCmdPlus');
    my $mylvl   = 0;
    $mylvl = $User->lvl if ($User);

    $irc->yield( notice => $Session->nick => "[$cmdname] Listing command:" );
    #print Dumper $C->cmd;
    for my $cmd ( sort keys %{ $C->cmd } ) {
        my $plugin = $C->cmd->{$cmd}->{plugin}->cmd->{$cmd};
#        LOG( "Show cmd '$cmd': " . $plugin->{lvl} );
#        LOG( "Show cmd '$cmd': " . $plugin->{help_cmd} );
#        LOG( "Show cmd '$cmd': " . $plugin->{help_description} );
        next if $mylvl < $plugin->{lvl};
        $irc->yield( notice => $Session->nick => " " . $plugin->{help_cmd});# . "   -   " . $plugin->{help_description});
#        $irc->yield( notice => $Session->nick => "    -> "
#              . $plugin->{help_description} );
    }
    return PCI_EAT_ALL;
}

1;
