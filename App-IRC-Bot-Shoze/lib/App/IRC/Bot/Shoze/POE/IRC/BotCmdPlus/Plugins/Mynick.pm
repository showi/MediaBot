package App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::Mynick;

use strict;
use warnings;

use Carp;

use POE::Component::IRC::Plugin qw(:ALL);

use Data::Dumper;

use lib qw(../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::String;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Helper qw(get_cmd);

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

            #            'help' => {
            #                access           => 'msg',
            #                lvl              => 0,
            #                help_cmd         => '!help',
            #                help_description => 'Listing available command',
            #            },
        }
    );
    return $s;
}

sub PCI_register {
    my ( $s, $irc ) = splice @_, 0, 2;
    $irc->plugin_register( $s, 'SERVER', qw(433) );
    my $C = $irc->plugin_get('BotCmdPlus');
    for my $cmd ( %{ $s->cmd } ) {
        $C->register_command(
            $s, $cmd,
            $s->cmd->{$cmd}->{access},
            $s->cmd->{$cmd}->{lvl}
        );
    }
    return 1;
}

sub PCI_unregister {
    my ( $s, $irc ) = splice @_, 0, 2;
    my $C = $irc->plugin_get('BotCmdPlus');
    for my $cmd ( %{ $s->cmd } ) {
        $C->unregister_command($cmd);
    }
    return 1;
}

sub S_433 {
    my ( $self, $irc ) = splice @_, 0, 2;

    #my ( $who, $where ) = ( ${ $_[0] }, ${ $_[1] } );
    #my ( $nick, $user, $hostmask ) = parse_user($who);
    #my $oldnick = (split(/\s+/, ${$_[1]}))[0];
    my $newnick;
    if ($irc->nick_name eq $irc->{Config}->bot->{nick}) {
        $newnick = $irc->nick_name . int(rand(100));
        $irc->yield( notify => $irc->{Config}->bot->{nick});
    } else {
        $newnick = $irc->{Config}->bot->{nick};
    }
    print "New Nick: $newnick\n";
    $irc->yield( nick => $newnick);
    return PCI_EAT_ALL;
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
        $irc->yield( notice => $Session->nick => " " . $plugin->{help_cmd} )
          ;    # . "   -   " . $plugin->{help_description});

        #        $irc->yield( notice => $Session->nick => "    -> "
        #              . $plugin->{help_description} );
    }
    return PCI_EAT_ALL;
}

1;
