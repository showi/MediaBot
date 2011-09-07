package App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::Apero;

use strict;
use warnings;

use Carp;

use POE::Component::IRC::Plugin qw(:ALL);
use IRC::Utils qw(:ALL);

use lib qw(../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::String;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Helper;

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
            'apero_add' => {
                access   => 'msg',
                lvl      => 800,
                help_cmd => '!apero.add <name> <trigger>',
                help_description => 'Add a new apero',
            },
            'apero_del' => {
                access   => 'msg',
                lvl      => 800,
                help_cmd => '!apero.del <name>',
                help_description => 'Deleting a give apero',
            },
            'apero_list' => {
                access   => 'msg',
                lvl      => 800,
                help_cmd => '!apero.list',
                help_description => 'List apero',
            },
            'apero_set' => {
                access           => 'msg',
                lvl              => 800,
                help_cmd         => '!apero.set <name> <trigger> <value>',
                help_description => 'Setting trigger for apero (require reloading)',
            },
            'apero_set_text' => {
                access           => 'msg',
                lvl              => 800,
                help_cmd         => '!apero.set.text <name> <index> <text>',
                help_description => 'Setting text at index',
            },
            'apero_set_chantext' => {
                access           => 'msg',
                lvl              => 800,
                help_cmd         => '!apero.set.chantext <name> <index> <text>',
                help_description => 'Setting channel text at index',
            },
            'apero_info' => {
                access           => 'msg',
                lvl              => 800,
                help_cmd         => '!apero.info <name>',
                help_description => 'Information about a given apero',
            },
        }
    );
    return $s;
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
              "[$cmdname] You don't have the right to set user key&value!" );
        return PCI_EAT_ALL;
    }
    my ( $cmd, $name, $key, $value ) = split /\s+/, str_chomp($msg);
    my @vkeys = qw(hostmask pending lvl);
    unless ( grep $key, @vkeys ) {
        $irc->yield(
            notice => $Session->nick => "[$cmdname] Invalid field '$key'" );
        return PCI_EAT_ALL;
    }
    my $UserTarget;
    unless ( $UserTarget = $db->Users->get_by({name =>$name}) ) {
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

sub apero_add {
    my ( $self, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'apero_add';
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
    if ( $NewUser = $db->Users->get_by({name =>$name}) ) {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] Username '$name' already exist!" );
        return PCI_EAT_ALL;
    }
    unless ( $password =~ /^[\w\d_-]+$/ ) {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] Invalid password $password" );
        return PCI_EAT_ALL;
    }
    if ($hostmask) {
        $hostmask = normalize_mask($hostmask);
    } else {
     $hostmask = "*!*@*" unless $hostmask;    
    }
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
    unless ( $TargetUser = $db->Users->get_by({name => $name}) ) {
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

sub user_list {
    my ( $self, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'user_list';
    my $PCMD    = $self->get_cmd($cmdname);
    my $db      = $irc->{database};

    unless ( $Session->user_id ) {
        $irc->yield(
            notice => $Session->nick => "[$cmdname] You must be logged!" );
        return PCI_EAT_ALL;
    }
    if ( $User->lvl < $PCMD->{lvl} ) {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] You don't have the right to list user!" );
        return PCI_EAT_ALL;
    }

    my @list = $db->Users->list;
    unless (@list) {
        $irc->yield(
            notice => $Session->nick => "[$cmdname] No user in database " );
        return PCI_EAT_ALL;
    }
    $irc->yield( notice => $Session->nick => "[$cmdname] Listing user " );
    for my $User (@list) {
        my $str = " - ";
        $str .= "[".$User->lvl."] " . $User->name . " / " . $User->hostmask;
        $str .= " [IsBot]" if $User->is_bot;
        $str .= " [Pending]" if $User->pending;
        $irc->yield( notice => $Session->nick => $str );
    }
    return PCI_EAT_ALL;
}

sub user_info {
    my ( $self, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'user_info';
    my $PCMD    = $self->get_cmd($cmdname);
    my $db      = $irc->{database};

    unless ( $Session->user_id ) {
        $irc->yield(
            notice => $Session->nick => "[$cmdname] You must be logged!" );
        return PCI_EAT_ALL;
    }
    if ( $User->lvl < $PCMD->{lvl} ) {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] You don't have the right to list channel!" );
        return PCI_EAT_ALL;
    }
    print "msg: $msg\n";
    my $name = ( split( /\s+/, $msg ) )[1];
    $name =~ /^([\w\d_-]+)$/ or do {
        $irc->yield(
            notice => $Session->nick => "[$cmdname] Invalid user name '$name'!" );
        return PCI_EAT_ALL;
    };
    my $TargetUser = $db->Users->get_by( { name => $name} );
    unless ($TargetUser) {
        $irc->yield( notice => $Session->nick =>
              "[$cmdname] User named $name not found!" );
        return PCI_EAT_ALL;
    }
    my $out = "User information [$name]\n";
    $out .= "lvl: " . $TargetUser->lvl . "\n";
    $out .= "hostmask: " . $TargetUser->hostmask . "\n";
    $out .= "pending: " . ($TargetUser->pending ? "Yes" : "No") . "\n";
    $out .= "is bot: " . ($TargetUser->is_bot? "Yes": "No") . "\n";
    $out .= "created on: " . localtime(int $TargetUser->created_on) . "\n";
    
    my @lines = split( /\n/, $out );
    $self->_send_lines( $irc, 'notice', $Session->nick, @lines );
    return PCI_EAT_ALL;
}
1;
