package App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Dispatch;

=head1 NAME

App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Dispatch - Dispatch plugin

=cut

=head1 SYNOPSIS

=cut

use strict;
use warnings;

use Carp;
use Encode qw(encode decode);

use POE;
use POE::Component::IRC::Plugin qw(:ALL);
use IRC::Utils qw(:ALL);

use lib qw(../../../../../../../);
use App::IRC::Bot::Shoze::Class qw(DESTROY);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::String;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Helper qw(_get_nick);

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
    return $s;
}

=item PCI_register

=cut

sub PCI_register {
    my ( $self, $irc ) = splice @_, 0, 2;

    # We store a ref to the $irc object so we can use it in our
    # session handlers.
    $self->{irc} = $irc;

    $irc->plugin_register( $self, 'SERVER', qw(msg public) );
    $irc->plugin_register( $self, 'USER',   'all' );
    POE::Session->create( object_states => [ $self => [qw(_start _shutdown)], ],
    );

    return 1;
}

=item PCI_unregister

=cut

sub PCI_unregister {
    my ( $self, $irc ) = splice @_, 0, 2;

    # Plugin is dying make sure our POE session does as well.
    $poe_kernel->call( $self->{SESSION_ID} => '_shutdown' );
    delete $self->{irc};
    return 1;
}

=item _start

=cut

sub _start {
    my ( $kernel, $self ) = @_[ KERNEL, OBJECT ];
    $self->{SESSION_ID} = $_[SESSION]->ID();

    # Make sure our POE session stays around. Could use aliases but that is so
    # messy :)
    $kernel->refcount_increment( $self->{SESSION_ID}, __PACKAGE__ );
    return;
}

=item _shutdown

=cut

sub _shutdown {
    my ( $kernel, $self ) = @_[ KERNEL, OBJECT ];
    $kernel->alarm_remove_all();
    $kernel->refcount_decrement( $self->{SESSION_ID}, __PACKAGE__ );
    return;
}

=item _default

We are dispatching all our commands here
 - We check each user input for command trigger
 - We check if user have the right to execute the command
 - We create a session with extended attributes that we pass to our plugins
=cut

sub _default {
    my ( $s, $irc, $event ) = splice @_, 0, 3;
    if ( $event =~ /^U_/ ) {
        DEBUG("Public Event: $event\n");
        return PCI_EAT_NONE;
    }
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    LOG( "Dispatcher[$event] $where/ $who / $msg", 3 );

    my $Config = App::IRC::Bot::Shoze::Config->new;
    my $prefix = $Config->bot->{cmd_prefix};

    ##########################################################################
    # Do we have a command
    ##########################################################################
    my ( $cmd, $cmd_args );
    if ( $event eq "S_msg" ) {
        $msg =~ /^($prefix)?([\w\d][\w\d._-]*)(\s+(.*))?$/ or do {
            LOG("Not a command");
            return PCI_EAT_NONE;
        };
        ( $cmd, $cmd_args ) = ( $2, str_chomp($3) );
    } else {
        $msg =~ /^$prefix([\w\d][\w\d._-]*)(\s+(.*))?$/ or do {
            LOG("Message not prefixed by '$prefix' so it's not a command");
            return PCI_EAT_NONE;
        };
        ( $cmd, $cmd_args ) = ( $1, str_chomp($2) );
    }
    $cmd =~ s/\./_/g;
    LOG("Got a command: $cmd [" . (defined $cmd_args? $cmd_args: '') . "]");
    my $Master = $irc->plugin_get("IRC_Core_BotCmdPlus");
    unless ( defined $Master->cmd->{$cmd} ) {
        LOG("No plugin have registered command '$cmd'");
        return PCI_EAT_NONE;
    }
    my $access = $Master->cmd->{$cmd}->{access};
    my $pat    = qr/^(S|U)_$access$/;
    unless ( $event =~ /$pat/ ) {
        LOG("Plugin not responding on $event '$cmd'");
        return PCI_EAT_NONE;
    }

    my $db      = App::IRC::Bot::Shoze::Db->new;
    my $Network = $irc->{Network}
      or croak "No registered Network object within irc session";

    ###########################################################################
    # Get Session Object
    ###########################################################################
    my ( $nick, $user, $hostname ) = parse_user($who);
    my $Nick = $s->_get_nick( $irc, $db, $Network, $nick );
    unless ($Nick) {
        WARN( "Cannot create nick '$nick' for network " . $Network->name );
        return PCI_EAT_NONE;
    }
    $db->NetworkSessions->delete_idle();
    my $Session = $db->NetworkSessions->get_extended( $Network,
                      { nick => $nick, user => $user, hostname => $hostname } );
    unless ($Session) {
        WARN("Cannot get session for $nick, $user, $hostname");
        return PCI_EAT_NONE;
    }
    $Session->last_access(time);
    $Session->_update();

    ##########################################################################
    # Fetching user information information
    ##########################################################################
    #    my $User;
    #    if ( $Session->user_id ) {
    #        $User = $db->Users->get_by( { id => $Session->user_id } );
    #    }

    my $pl  = $Master->cmd->{$cmd}->{plugin};
    my $lvl = $Master->cmd->{$cmd}->{lvl};

    ##########################################################################
    # Filtering command parameters
    ##########################################################################
    my @params = split /\s+/, $cmd_args;
    LOG( "Params: " . @params );
    if (@params) {
        my $filter = qr/^[\w\d]+$/;
        if ( defined $Master->cmd->{$cmd}->{argument_filter} ) {
            LOG("Got specific command filter");
            $filter = $Master->cmd->{$cmd}->{argument_filter};
        }
        $cmd_args = decode( 'utf8', $cmd_args );
        my $new_cmd_args =
          $s->string_filter( $irc, $Session, $cmd, $filter, @params );
        unless ( defined $new_cmd_args ) {
            return PCI_EAT_ALL;
        }
        ${ $_[2] } = "$prefix$cmd $new_cmd_args";
    } else {
        ${ $_[2] } = "$prefix$cmd";
    }
    ###########################################################################
    # Checking command levels
    ##########################################################################
    if ( $lvl > 0 ) {
        unless ( $Session->user_name ) {
            $irc->{Out}->notice( '#me#', $Session,
                                 "You must be logged to execute this command" );
            return PCI_EAT_ALL;
        }
        if ( $Session->user_lvl < $lvl ) {
            $irc->{Out}->notice( '#me#', $Session,
                           "You don't have the right to execute this command" );
            return PCI_EAT_ALL;
        }
    }
    
    LOG( "Calling $cmd on plugin $pl", 3 );
    #$irc->{Out}->log( 'dispatch', $who, $where, $msg );
    
    ###########################################################################
    # We are passing the original parameters so plugin can modify theirs values
    # for other plugins in the pipeline
    ###########################################################################
    $pl->$cmd( $Session, $irc, $event, @_ );
    return PCI_EAT_ALL;
}

=item string_filter

=cut

sub string_filter {
    my ( $s, $irc, $Session, $cmd, $filter, @params ) = @_;
    LOG("Filter: $filter");
    my $ref_filter = ref($filter);
    LOG( "Ref filter: " . ref($filter) );
    if ( $ref_filter eq 'CODE' ) {
        return &$filter( $irc, $Session, $cmd, @params );
    }
    my $rstr;
    if ( $ref_filter eq 'ARRAY' ) {
        unless ( scalar(@params) == scalar(@$filter) ) {
            $irc->{Out}->notice( '#me#', $Session,
                               "$cmd need " . scalar(@$filter) . " arguments." );
            return undef;
        }
        for (@$filter) {
            my $arg = shift @params;
            if ( $arg !~ /$_/ ) {
                $irc->{Out}
                  ->notice( '#me#', $Session, "Invalid parameter '$arg'" );
                return undef;
            }
            $rstr .= $arg . ' ';
        }
    } elsif ( $ref_filter eq 'Regexp' ) {
        for my $arg (@params) {
            unless ( $arg =~ /$filter/ ) {
                $irc->{Out}
                  ->notice( '#me#', $Session, "Invalid parameter '$arg'" );
                return undef;
            }
            $rstr .= "$arg ";

        }
    } else {
        WARN("Unknow filter type: $ref_filter for command $cmd");
        return undef;
    }
    $rstr =~ s/^(.*)\s+$/$1/ if $rstr;
    return $rstr;
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
