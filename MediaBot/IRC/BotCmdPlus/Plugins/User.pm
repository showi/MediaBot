package MediaBot::IRC::BotCmdPlus::Plugins::User;

use strict;
use warnings;

use Carp;

use POE::Component::IRC::Plugin qw(:ALL);

use lib qw(../../../../);
use MediaBot::Class qw(AUTOLOAD);
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
    $s->cmd({
        
            'login' => {
                access           => 'msg',
                lvl              => 0,
                help_cmd         => '!login name password',
                help_description => 'Identifying you againt the bot!',
            },
            'logout' => {
                access           => 'msg',
                lvl              => 200,
                help_cmd         => '!logout',
                help_description => 'Close current session!',
            },
        }
    );
    return $s;
}

sub login {
    my ( $self, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'login';
    my $PCMD    = $self->get_cmd($cmdname);
    my $C       = $irc->plugin_get('BotCmdPlus');
    my $db = $irc->{database};

    if ( $Session->user_id ) {
        $irc->yield(
            privmsg => $Session->nick => '# login: already logged' );
        return PCI_EAT_ALL;
    }
    my ( $cmd, $user, $password ) = split( /\s+/, $msg );
    LOG("We need to authenticate user '$user' with password '$password'");

    $User = $db->Users->get_byname($user);
    unless ($User) {
        $irc->yield( privmsg => $Session->nick => '# login: invalid username' );
        return PCI_EAT_ALL;
    }
    unless ( $db->Users->check_password( $User, $password ) ) {
        $irc->yield( privmsg => $Session->nick => '# login: invalid password' );
        return PCI_EAT_ALL;
    }
    $irc->yield( privmsg => $Session->nick => '# login: ok your in!' );
    $Session->user_id( $User->id );
    $db->Sessions->update($Session);
    return PCI_EAT_ALL;
}

sub logout {
    my ( $self, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'logout';
    my $PCMD    = $self->get_cmd($cmdname);
    my $C       = $irc->plugin_get('BotCmdPlus');
    my $db = $irc->{database};
    
    unless ( defined $Session->user_id ) {
        $irc->yield(
            privmsg => $Session->nick => "# login: you're not logged" );
        return PCI_EAT_ALL;
    }
    $Session->user_id(undef);
    $db->Sessions->update($Session);
    $irc->yield( privmsg => $Session->nick => "# bye!" );
    return PCI_EAT_ALL;
}


1;
