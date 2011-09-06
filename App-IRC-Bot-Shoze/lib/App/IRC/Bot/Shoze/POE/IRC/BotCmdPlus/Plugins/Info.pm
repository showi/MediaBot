package App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::Info;

use strict;
use warnings;

use Carp;

use POE;
use POE::Component::IRC::Plugin qw(:ALL);

use lib qw(../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::String;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Helper;

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
    no warnings;
    my $version = "I'm running $App::IRC::Bot::Shoze::PROGRAMNAME($App::IRC::Bot::Shoze::VERSION)";
    use warnings;
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
