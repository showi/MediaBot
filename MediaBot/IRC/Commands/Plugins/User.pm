package MediaBot::IRC::Commands::Plugins::User;

use strict;
use warnings;

use Carp;

use lib qw(../../../../);
use MediaBot::Class qw(AUTOLOAD DESTROY _get_root);
use MediaBot::Log;
use MediaBot::Constants;
use MediaBot::String;

use POE::Session;

our $AUTOLOAD;

our %fields = (
    _parent        => undef,
    cmd            => undef,
    lvl            => undef,
    description    => undef,
    on             => undef,
    registered_cmd => undef,
);

# Constructor
#############
sub new {
    my ( $proto, $parent ) = @_;
    DEBUG( "Creating new " . __PACKAGE__ );
    croak "No parent specified" unless ref $parent;
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    $s->_parent($parent);
    $s->cmd('version');
    my @cmds = qw(login logout);
    $s->registered_cmd( \@cmds );
    return $s;
}

sub login {
    my ( $s, $CO ) = @_;
    my ( $sender, $where, $what ) = @{ $CO->args }[ SENDER, ARG1 .. ARG2 ];
    my $nick = $CO->User->nick;
    my $channel = $where;
    my $irc = $sender->get_heap();
    
    if ($CO->type == IRCCMD_TYPE_PUB) {
          $irc->yield( privmsg => $nick =>
          "You have issued login command on channel, your credentials may have been compromised!" );
        return;
    }
    my $db = $s->_get_root->Db->Users;
    my $user = $db->get_byidenthost($CO->User->ident, $CO->User->host);
    if ($user) {
          $irc->yield( privmsg => $nick =>
          "You are already logged!");
        return;
    }    
    my $params = str_chomp($CO->cmd_parameters);
    unless($params =~ /^[^\s]{3,9}\s+[^\s]{6,16}$/) {
        $irc->yield( privmsg => $nick =>
          "[error] Login syntax: !login [username{3,9}] [password{6,16}]");
        return;
    }
    my ($login, $pass) = split '\s+', $params;
    my $nlogin = esc_nick($login);
    my $npass = esc_password($pass);
    if (($nlogin ne $login) or ($npass ne $pass)) {
        $irc->yield( privmsg => $nick =>
          "[error] Invalid character in your login or password!");
        return;
    }
    #my $db = $s->_get_root->Db->Users;
    $user = $db->get_byname($login);
    unless ($user) {
        $irc->yield( privmsg => $nick => "Login failure!");
        return 0;
    } 
    if ($db->check_password($user, $npass)) {
        $db->login_successfull($user->id, $CO->User->ident, $CO->User->host);
        $irc->yield( privmsg => $nick => "Login successful!");
        return 1;
    } else {
        $irc->yield( privmsg => $nick => "Login failure!");
        return 0;
    }
    return 0;
}

sub logout {
    my ( $s, $CO ) = @_;
    my ( $sender, $where, $what ) = @{ $CO->args }[ SENDER, ARG1 .. ARG2 ];
    my $nick = $CO->User->nick;
    my $channel = $where;
    my $irc = $sender->get_heap();
    
    if ($CO->type == IRCCMD_TYPE_PUB) {
        return 1;
    }
    my $db = $s->_get_root->Db->Users;
    my $user = $db->get_byidenthost($CO->User->ident, $CO->User->host);
    unless ($user) {
       $irc->yield( privmsg => $nick => "You are not logged!" );
        return 2;
    }
    $db->logout($user->id);
    $irc->yield( privmsg => $nick => "You have been logged out!" );
    return 0;
}

1;
