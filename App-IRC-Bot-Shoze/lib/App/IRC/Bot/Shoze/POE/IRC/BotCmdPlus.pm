package App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus;

use strict;
use warnings;

use Carp;
use POE;
use POE::Component::IRC::Plugin qw(:ALL);

use lib qw(../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY);
use App::IRC::Bot::Shoze::Constants;
use App::IRC::Bot::Shoze::Log;

use Data::Dumper qw(Dumper);

our %fields = ( cmd => undef, );

sub new {
    my ($proto) = @_;
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    $s->cmd( {} );
    return $s;
}

sub PCI_register {
    my ( $self, $irc ) = splice @_, 0, 2;
    $irc->{USER_SESSION}= {};
    #$irc->plugin_register( $self, 'USER',   qw(msg public) );
    #$irc->plugin_register( $self, 'SERVER', qw(msg public) );
    return 1;
}

sub PCI_unregister {
    my ($self) = @_;
    delete $self->{irc};
    return 1;
}

sub _default {
    my ( $self, $irc, $event ) = splice @_, 0, 3;
    my $msg = ${ $_[2] };

    return PCI_EAT_NONE unless $msg =~ /^!/;
}

sub _S_msg {
    my ( $kernel, $self, $session ) = @_[ KERNEL, OBJECT, SESSION ];

    my $who   = ${ $_[ARG0] };
    my $where = ${ $_[ARG1] };
    my $msg   = ${ $_[ARG2] };

    my $prefix = substr $msg, 0, 1;
    if ( $prefix ne '!' ) {
        return PCI_EAT_NONE;
    }
    $msg = substr $msg, 1;

    print "Command: '$msg'\n";
    $msg =~ /^([a-z0-9_-]+)(\s+(.*))?$/;
    my ( $cmd, $args ) = ( $1, $2 );
    unless ($cmd) {
        return PCI_EAT_NONE;
    }
    my $event = "irc_botcmd_$cmd";
    print "Event $event\n";
    $self->{irc}->send_event( 'irc_botcmd_version', $who, $where, $msg );

    return PCI_EAT_ALL;
}

sub _start {
    my ( $kernel, $self ) = @_[ KERNEL, OBJECT ];
    print "Starting session " . $self->{session_id} . "\n";
    $self->{session_id} = $_[SESSION]->ID();
    $kernel->refcount_increment( $self->{session_id}, __PACKAGE__ );
    return;
}

sub _shutdown {
    print "Stop session:\n";

}

sub register_command {
    my ( $s, $plugin, $cmd, $acces, $lvl ) = @_;
    return if ref($cmd); ### Dirty hack, something's going wrong on plugin registration###
    DEBUG("Registering command $cmd with access level $lvl ($plugin)", 2);
    croak "Cannot register command '$cmd'"
      if defined $s->cmd->{$cmd};
    $s->cmd->{$cmd} = {
        plugin => $plugin,
        lvl    => $lvl,
        access  => $acces,
    };
}

sub unregister_command {
    my ( $s, $cmd ) = @_;
    DEBUG("Unregistering command $cmd", 2);
    delete $s->cmd->{$cmd} if $s->cmd->{$cmd};
}

1;
