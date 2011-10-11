package App::IRC::Bot::Shoze::Plugins::IRC::Users::Main;

=head1 NAME

App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::Users - Users plugin

=cut

=head1 SYNOPSIS

This plugin allow user to login, logout and for administrator to manage
users (add, del, view information, change values)

=cut

use strict;
use warnings;

use Carp;

our $VERSION           = '0.0.1';
our $MAINCOMPATIBILITY = '0.0.8';

use POE::Component::IRC::Plugin qw(:ALL);
use IRC::Utils qw(:ALL);
use Crypt::Passwd::XS;

use lib qw(../../../../../../../);
use App::IRC::Bot::Shoze::i18n;
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::String;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Helper qw(:ALL);

use Data::Dumper qw(Dumper);

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
           'login' => {
                        access           => 'msg',
                        lvl              => 0,
                        help_cmd         => '!login name password',
                        help_description => 'Identifying you againt the bot!',
                        argument_filter  => [
                                  $App::IRC::Bot::Shoze::String::regexp_user,
                                  $App::IRC::Bot::Shoze::String::regexp_password
                        ],
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
                      help_cmd => '!user.add <user name> <password> [hostmask]',
                      help_description => 'Add a new user',
                      argument_filter  => [
                                 $App::IRC::Bot::Shoze::String::regexp_user,
                                 $App::IRC::Bot::Shoze::String::regexp_password,
                                 $App::IRC::Bot::Shoze::String::regexp_hostmask
                      ],
           },
           'user_del' => {
                access           => 'msg',
                lvl              => 800,
                help_cmd         => '!user.del <user name>',
                help_description => 'Delete a given user',
                argument_filter => [$App::IRC::Bot::Shoze::String::regexp_user],
           },
           'user_set' => {
                  access => 'msg',
                  lvl    => 200,
                  help_cmd =>
                    '!user.set <username> <hostmask|pending|lvl> <value>',
                  help_description => 'Adding user',
                  argument_filter  => [
                                  $App::IRC::Bot::Shoze::String::regexp_user,
                                  $App::IRC::Bot::Shoze::String::regexp_user,
                                  $App::IRC::Bot::Shoze::String::regexp_hostmask
                  ],
           },
           'user_list' => {
                            access           => 'msg',
                            lvl              => 800,
                            help_cmd         => '!user.list',
                            help_description => 'Lisging user',
           },
           'user_info' => {
                 access           => 'msg',
                 lvl              => 200,
                 help_cmd         => '!user.info <user name>',
                 help_description => 'Information about a given user',
                 argument_filter => [$App::IRC::Bot::Shoze::String::regexp_user]
           },
         }
    );
    return $s;
}

=item login

=cut

sub login {
    my ( $s, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'login';
    my $PCMD    = $s->get_cmd($cmdname);
    my $C       = $irc->plugin_get('BotCmdPlus');
    my $db      = $Session->_object_db;
    my $lh      = $Session->_lh;

    return
      $s->_n_error( $irc, $Session,
                    "[$cmdname] " . $lh->maketext('Already logged in') )
      if $Session->user_id;

    my ( $cmd, $user, $password ) = split( /\s+/, $msg );
    return
      $s->_n_error( $irc, $Session,
                    "[$cmdname] " . $lh->maketext('No password supplied') )
      unless $password;

    LOG("We need to authenticate user '$user' with password '$password'");
    my $User = $db->Users->get_by( { name => $user } );
    return
      $s->_n_error( $irc, $Session,
           "[$cmdname] " . $lh->maketext( 'Invalid username \'[_1]\'', $user ) )
      unless $User;

    unless ( matches_mask( $User->hostmask, $who ) ) {
        return
          $s->_n_error( $irc, $Session,
                     "[$cmdname] " . $lh->maketext('Hostmask doesn\'t match') );
    }
    unless ( $db->Users->check_password( $User, $password ) ) {
        return
          $s->_n_error( $irc, $Session,
                        "[$cmdname] " . $lh->maketext('Invalid password') );
    }
    if ( $User->pending ) {
        return
          $s->_n_error( $irc, $Session,
                   "[$cmdname] " . $lh->maketext('You\'re on pending status') );
    }
    $Session->user_id( $User->id );
    $db->NetworkSessions->update($Session);
    print Dumper $Session;
    $irc->{Out}->respond_user( $Session,
                  "[$cmdname] " . $lh->maketext( 'Logged in as [_1]', $user ) );
    return PCI_EAT_ALL;
}

=item logout

=cut

sub logout {
    my ( $s, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'logout';
    my $PCMD    = $s->get_cmd($cmdname);
    my $C       = $irc->plugin_get('BotCmdPlus');
    my $db      = $Session->_object_db;
    my $lh      = $Session->_lh;

    unless ( defined $Session->user_id ) {
        return
          $s->_n_error( $irc, $Session,
                        "[$cmdname] " . $lh->maketext('You are not logged') );
    }
    $Session->user_id(undef);
    $db->NetworkSessions->update($Session);
    $irc->{Out}
      ->respond_user( $Session, "[$cmdname] " . $lh->maketext('Bye!') );
    return PCI_EAT_ALL;
}

=item user_set

=cut

sub user_set {
    my ( $s, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'user_set';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = $Session->_object_db;
    my $lh      = $Session->_lh;

    my ( $cmd, $name, $key, $value ) = split /\s+/, str_chomp($msg);
    my @vkeys;
    if ( $Session->user_lvl < 800 ) {
        $name  = $Session->user_name;
        @vkeys = qw(hostmask password);
    } else {
        @vkeys = qw(password hostmask pending lvl);
    }
    unless ( grep /^$key$/, @vkeys ) {
        return $s->_n_error( $irc, $Session,
                             "[$cmdname] Invalid field '$key'" );
    }
    my $UserTarget;
    unless ( $UserTarget = $db->Users->get_by( { name => $name } ) ) {
        return
          $s->_n_error( $irc, $Session,
                        "[$cmdname] Username '$name' doesn't exist!" );
    }
    if ( $Session->user_lvl < 800 ) {
        if ( $UserTarget->id != $Session->user_id ) {
            return
              $s->_n_error(
                $irc,
                $Session,
"[$cmdname] You don't have the right to modify other user settings"
              );
        }
    }
    if ( $key eq 'hostmask' ) {
        $value = normalize_mask($value);
    } elsif ( $key eq 'lvl' ) {
        $value = abs( int($value) );
        if ( $value >= $Session->user_lvl ) {
            return
              $s->_n_error(
                 $irc,
                 $Session,
                 "[$cmdname] You cannot set user lvl higher or equal than yours"
              );
        }
        if ( $UserTarget->lvl >= $Session->user_lvl ) {
            return
              $s->_n_error(
                $irc,
                $Session,
"[$cmdname] You cannot set user lvl to user with same lvl or above!"
              );
        }
    } elsif ( $key eq 'pending' ) {
        $value = abs( int($value) );
        $value = 1 if $value;
    } elsif ( $key eq 'password' ) {
        my $Config = App::IRC::Bot::Shoze::Config->new;
        my $salt = $Config->bot->{password_salt};
        $value = Crypt::Passwd::XS::crypt( $value, $salt );
    } else {
        return $s->_n_error( $irc, $Session,
                             "[$cmdname] Invalid field '$key'" );
    }
    $UserTarget->$key($value);
    my $res = $UserTarget->_update();
    if ($key eq 'password') {
        $value = '*****';
    }
    #$db->Users->set( $UserTarget->id, $key, $value );
    if ($res) {
        $irc->{Out}
          ->respond_user( $Session, "[$cmdname] '$name' $key set to '$value'" );
    } else {
        return
          $s->_n_error( $irc, $Session,
                        "[$cmdname] '$name' Cannot set $key to '$value'" );
    }
    return PCI_EAT_ALL;
}

=item user_add

=cut

sub user_add {
    my ( $s, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'user_add';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = $Session->_object_db;
    my $lh      = $Session->_lh;

    my ( $cmd, $name, $password, $hostmask ) = split /\s+/, $msg;
    unless ( is_valid_nick_name($name) ) {
        return
          $s->_n_error(
                        $irc,
                        $Session,
                        "[$cmdname] "
                          . $lh->maketext( 'Invalid username \'[_1]\'', $name )
          );
    }
    my $NewUser;
    if ( $NewUser = $db->Users->get_by( { name => $name } ) ) {
        return
          $s->_n_error(
                        $irc,
                        $Session,
                        "[$cmdname] "
                          . $lh->maketext( 'User \'[_1]\' already exist',
                                           $name )
          );
    }
    unless ( $password =~ /^[\w\d_-]+$/ ) {
        return
          $s->_n_error( $irc, $Session,
                        "[$cmdname] " . $lh->('Invalid password') );
    }
    if ($hostmask) {
        $hostmask = normalize_mask($hostmask);
    } else {
        $hostmask = "*!*@*" unless $hostmask;
    }
    LOG("Adding user $name with password $password [$hostmask]");
    my $res = $db->Users->create( $name, $password, $hostmask );
    if ($res) {
        $irc->{Out}->respond_user( $Session,
                       "[$cmdname] " . $lh->maketext('User \'[_1]\' created') );
    } else {
        return
          $s->_n_error(
                        $irc,
                        $Session,
                        "[$cmdname] "
                          . $lh->maketext( 'Cannot create user \'[_1]\'',
                                           $name )
          );
    }
    return PCI_EAT_ALL;
}

=item user_del

=cut

sub user_del {
    my ( $s, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'user_del';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = $Session->_object_db;
    my $lh      = $Session->_lh;

    my ( $cmd, $name ) = split /\s+/, $msg;

    my $TargetUser;
    unless ( $TargetUser = $db->Users->get_by( { name => $name } ) ) {
        return
          $s->_n_error(
                        $irc,
                        $Session,
                        "[$cmdname] "
                          . $lh->maketext( 'Invalid username \'[_1]\'', $name )
          );
    }
    if ( $TargetUser->lvl >= $Session->user_lvl ) {
        return
          $s->_n_error(
                        $irc, $Session,
                        "[$cmdname] "
                          . $lh->maketext(
'You cannot delete user with higher or same level as you'
                          )
          );
    }
    DEBUG( "Delete user with id: " . $TargetUser->id, 4 );
    my $res = $TargetUser->_delete;
    if ($res) {
        $irc->{Out}->respond_user(
                                   $Session,
                                   "[$cmdname] "
                                     . $lh->maketext(
                                           'User \'[_1]\' successfully deleted',
                                           $name
                                     )
        );
    } else {
        return
          $s->_n_error(
                        $irc,
                        $Session,
                        "[$cmdname] "
                          . $lh->maketext( 'Cannot delete user \'[_1]\'',
                                           $name )
          );
    }
    return PCI_EAT_ALL;
}

=item user_list

=cut

sub user_list {
    my ( $s, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'user_list';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = $Session->_object_db;
    my $lh      = $Session->_lh;

    my @list = $db->Users->list;
    unless (@list) {
        return
          $s->_n_error( $irc, $Session,
                        "[$cmdname] " . $lh->maketext('No user in database') );
    }
    $irc->{Out}->respond_user( $Session,
                               "[$cmdname] " . $lh->maketext('Listing users') );
    for my $User (@list) {
        my $str = " - ";
        $str .= "[" . $User->lvl . "] " . $User->name . " / " . $User->hostmask;
        $str .= " [" . $lh->maketext('is bot') . "]" if $User->is_bot;
        $str .= " [" . $lh->maketext('pending') . "]" if $User->pending;
        $irc->{Out}->respond_user( $Session, $str );
    }
    return PCI_EAT_ALL;
}

=item user_info

=cut

sub user_info {
    my ( $s, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'user_info';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = $Session->_object_db;
    my $lh      = $Session->_lh;

    my $name;
    if ( $Session->user_lvl < 800 ) {
        $name = $Session->user_name;
    } else {
        $name = ( split( /\s+/, $msg ) )[1];
    }
    my $TargetUser = $db->Users->get_by( { name => $name } );
    unless ($TargetUser) {
        return
          $s->_n_error(
                        $irc,
                        $Session,
                        "[$cmdname] "
                          . $lh->maketext( 'Invalid username \'[_1]\'', $name )
          );
    }
    my $lh_yes = $lh->maketext('yes');
    my $lh_no  = $lh->maketext('no');
    my $out =
      "[$cmdname] " . $lh->maketext('User information') . ": " . $name . "\n";
    $out .= ' - ' . $lh->maketext('level') . ': ' . $TargetUser->lvl . "\n";
    $out .=
      ' - ' . $lh->maketext('hostmask') . ': ' . $TargetUser->hostmask . "\n";
    $out .= ' - '
      . $lh->maketext('pending') . ': '
      . ( $TargetUser->pending ? $lh_yes : $lh_no ) . "\n";
    $out .= ' - '
      . $lh->maketext('is bot') . ': '
      . ( $TargetUser->is_bot ? $lh_yes : $lh_no ) . "\n";
    $out .= ' - ' . $lh->maketext('language') . ': ' . $TargetUser->lang . "\n";
    $out .= ' - '
      . $lh->maketext('output') . ': '
      . $TargetUser->output_method . "\n";
    $out .=
        ' - ' 
      . $lh->maketext('created on') . ': '
      . (
          $TargetUser->created_on
          ? localtime( int $TargetUser->created_on )
          : ''
      ) . "\n";
    my @lines = split( /\n/, $out );
    $irc->{Out}->respond_user_lines( $Session, @lines );
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
