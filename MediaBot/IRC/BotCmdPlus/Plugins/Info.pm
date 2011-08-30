package MediaBot::IRC::BotCmdPlus::Plugins::Info;

use strict;
use warnings;

use Carp;

use POE;
use POE::Component::IRC::Plugin qw(:ALL);

use lib qw(../../../../);
use MediaBot::Class qw(AUTOLOAD);
use MediaBot::Log;
use MediaBot::String;
use MediaBot::IRC::BotCmdPlus::Helper;

use Data::Dumper;

our %fields = ( cmd => undef, );

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

sub version {
    my ( $self, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'version';
    my $PCMD    = $self->get_cmd($cmdname);

    # Parameters are passed as scalar-refs including arrayrefs.
    my $nick    = $Session->nick;
    my $channel = $where->[0];
    #my $msg     = ${ $_[2] };

    my $version = "I'm running $MediaBot::PROGRAMNAME($MediaBot::VERSION)";
    $where   = $nick;
    if ( $event =~ /^\w_public$/ ) {
        $where = $channel;
    }
    $irc->yield( privmsg => $where => $version );
    return PCI_EAT_ALL;
}

#sub _default {
#    my ( $self, $irc ) = splice @_, 0, 2;
#    print __PACKAGE__ . " Unprocessed event: " . $_[STATE][0] . "\n";
#}

1;
