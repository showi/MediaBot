package MediaBot::IRC::BotCmdPlus::Plugins::User;

use strict;
use warnings;

use Carp;

use POE::Component::IRC::Plugin qw(:ALL);
use IRC::Utils qw(:ALL);

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
            'user_add' => {
                access   => 'msg',
                lvl      => 800,
                help_cmd => '!user.add [user name] [password] <hostmask>',
                help_description => 'Adding user',
            },
            'user_del' => {
                access   => 'msg',
                lvl      => 800,
                help_cmd => '!user.del [user name] ',
                help_description => 'Deleting user',
            },
            'user_set' => {
                access           => 'msg',
                lvl              => 800,
                help_cmd         => '!user.set [username] [hostmask|pending|lvl] [value]',
                help_description => 'Adding user',
            },
            'user_list' => {
                access           => 'msg',
                lvl              => 800,
                help_cmd         => '!user.list',
                help_description => 'Lisging user',
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
    my $db      = $irc->{database};

    if ( $Session->user_id ) {
        $irc->yield( notice => $Session->nick => "[$cmdname] Already logged" );
        return PCI_EAT_ALL;
    }
    my ( $cmd, $user, $password ) = split( /\s+/, $msg );
    LOG("We need to authenticate user '$user' with password '$password'");

    $User = $db->Users->get_by($user);
    unless ($User) {
        $irc->yield( notice => $Session->nick => "[$cmdname] Invalid username" );
        return PCI_EAT_ALL;
    }
    unless(matches_mask($User->hostmask, $who)) {
              $irc->yield( notice => $Session->nick => "[$cmdname] Hostmask doesn't match"  );
        return PCI_EAT_ALL;  
    }
    unless ( $db->Users->check_password( $User, $password ) ) {
        $irc->yield( notice => $Session->nick => "[$cmdname] Invalid password" );
        return PCI_EAT_ALL;
    }
    $irc->yield( notice => $Session->nick => "[$cmdname] Ok you're in" );
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
    my $db      = $irc->{database};

    unless ( defined $Session->user_id ) {
        $irc->yield(
            notice => $Session->nick => "[$cmdname] You're not logged" );
        return PCI_EAT_ALL;
    }
    $Session->user_id(undef);
    $db->Sessions->update($Session);
    $irc->yield( notice => $Session->nick => "[$cmdname] Bye!" );
    return PCI_EAT_ALL;
}

sub user_set {
    my ( $self, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'user_set';
    my $PCMD    = $self->get_cmd($cmdname);
    my $db      = $irc->{database};
    unless ( $Session->user_id ) {
        $irc->yield(
            notice => $Session->nick => "[$cmdname] You must be logged!" );
        return PCI_EAT_ALL;
    }
    if ( $User->lvl < $PCMD->{lvl} ) {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] You don't have the right to add user!" );
        return PCI_EAT_ALL;
    }
    my ( $cmd, $name, $key, $value ) = split /\s+/, $msg;
    my @vkeys = qw(hostmask pending level);
    unless ( grep $key, @vkeys ) {
        $irc->yield(
            notice => $Session->nick => "[$cmdname] Invalid field '$key'" );
        return PCI_EAT_ALL;
    }
    my $UserTarget;
    unless ( $UserTarget = $db->Users->get_by($name) ) {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] Username '$name' doesn't exist!" );
        return PCI_EAT_ALL;
    }
    if ( $key eq 'hostmask' ) {
        $value = normalize_mask($value);
    }
    elsif ( $key eq 'lvl' ) {
        $value = abs( int($value) );
        if ( $value >= $User->lvl ) {
            $irc->yield( notice => $Session->nick =>
                  "[$cmdname] You cannot set user lvl higher or equal than yours" );
            return PCI_EAT_ALL;
        }
        if ($UserTarget->lvl >= $User->lvl) {
            $irc->yield( notice => $Session->nick =>
                  "[$cmdname] You cannot set user lvl to user with same lvl or above!" );
            return PCI_EAT_ALL;
        }
    }
    elsif ( $key eq 'pending' ) {
        $value = abs( int($value) );
        $value = 1 if $value;
    }
    else {
        $irc->yield(
            notice => $Session->nick => "[$cmdname] Invalid field '$key'" );
        return PCI_EAT_ALL;
    }
    $UserTarget->$key($value);
    my $res = $UserTarget->_update();
    #$db->Users->set( $UserTarget->id, $key, $value );
    if ($res) {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] '$name' $key set to '$value'" );
    }
    else {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] '$name' Cannot set $key to '$value'" );
    }
}

sub user_add {
    my ( $self, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'user_add';
    my $PCMD    = $self->get_cmd($cmdname);
    my $db      = $irc->{database};

    unless ( $Session->user_id ) {
        $irc->yield(
            notice => $Session->nick => "[$cmdname] You must be logged!" );
        return PCI_EAT_ALL;
    }
    if ( $User->lvl < $PCMD->{lvl} ) {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] You don't have the right to add user!" );
        return PCI_EAT_ALL;
    }
    my ( $cmd, $name, $password, $hostmask ) = split /\s+/, $msg;
    unless ( is_valid_nick_name($name) ) {
        $irc->yield(
            notice => $Session->nick => "[$cmdname] Invalid username $name" );
        return PCI_EAT_ALL;
    }
    my $NewUser;
    if ( $NewUser = $db->Users->get_by($name) ) {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] Username '$name' already exist!" );
        return PCI_EAT_ALL;
    }
    unless ( $password =~ /^[\w\d_-]+$/ ) {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] Invalid password $password" );
        return PCI_EAT_ALL;
    }
    $hostmask = normalize_mask($hostmask);
    LOG("Adding user $name with password $password [$hostmask]");

    my $res = $db->Users->create($name, $password, $hostmask);
    if ($res) {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] Successfully created user '$name'" );
    }
    else {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] Cannot create user '$name'" );
    }
}

sub user_del {
    my ( $self, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'user_del';
    my $PCMD    = $self->get_cmd($cmdname);
    my $db      = $irc->{database};

    unless ( $Session->user_id ) {
        $irc->yield(
            notice => $Session->nick => "[$cmdname] You must be logged!" );
        return PCI_EAT_ALL;
    }
    if ( !$User or ($User->lvl < $PCMD->{lvl}))  {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] You don't have the right to add user!" );
        return PCI_EAT_ALL;
    }
    my ( $cmd, $name ) = split /\s+/, $msg;
    unless ( is_valid_nick_name($name) ) {
        $irc->yield(
            notice => $Session->nick => "[$cmdname] Invalid username $name" );
        return PCI_EAT_ALL;
    }
    my $TargetUser;
    unless ( $TargetUser = $db->Users->get_by($name) ) {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] Username '$name' doesn't exist!" );
        return PCI_EAT_ALL;
    }
    if ( $TargetUser->lvl >= $User->lvl ) {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] You cannot delete user with higer or same lvl as you!"
        );
        return PCI_EAT_ALL;
    }
    print "Deleting user id: " . $TargetUser->id . "\n";
    my $res = $TargetUser->_delete;
    if ($res) {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] Successfully deleted user '$name'" );
    }
    else {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] Cannot delete user '$name'" );
    }
}
1;
