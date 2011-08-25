package MediaBot::IRC::Commands;
use strict;
use warnings;

use Carp;
use Exporter;

use POE::Session;

use lib qw(../../);
use MediaBot::Class qw(AUTOLOAD DESTROY _get_root);
use MediaBot::Log;
use MediaBot::Constants;
use MediaBot::IRC::Commands::Plugins;
use MediaBot::IRC::Commands::Object;
use MediaBot::String;
use MediaBot::IRC::User;

our @ISA    = qw(Exporter);
our @EXPORT = qw(irc_botcmd_version irc_botcmd_register);

our $AUTOLOAD;

our %fields = (
    _parent    => undef,
    cmd_prefix => undef,
    Plugins    => undef,
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
    $s->Plugins( new MediaBot::IRC::Commands::Plugins($s) );
    my $cmd_prefix = $s->_get_root->Config->bot->{cmd_prefix};
    croak "Unconfigured or bad cmd_prefix in bot.yaml config"
      unless $cmd_prefix =~ /^[!.]$/;
    $s->cmd_prefix($cmd_prefix);
    return $s;
}

1;

sub _cleanstr {
    return str_asciionly( str_chomp(shift) );
}

sub dispatch {
    my $s    = shift;
    my $type = shift;

    my $cmd_prefix = $s->cmd_prefix;
    return unless $_[ARG2] =~ /^$cmd_prefix[a-z0-9_-]+/;

    my $user = new MediaBot::IRC::User();
    $user->parse_event(@_);

    print "Dispatching $type command for user: " . $user->pretty_print . "\n";
    my $US =
      $s->_parent->Sessions->add( $user->nick, $user->ident, $user->host );
    unless ($US) {
        print "Cannot create user session, returning!\n";
        return 1;
    }
    if ( $US->ignore ) {
        print "Ignored user\n";
        return 2;
    }
    my $args = substr( $_[ARG2], 1 );
    $args =~ s/^([a-zA-Z0-9_-]+)\s*(.*)\s*$/$2/;
    my $cmd = $1;
    print "Dispatching command: '$cmd' ($args)\n";
    unless ( $s->Plugins->exists($cmd) ) {
        print "Unknown command '$cmd\n";
        return 3;
    }
    my $co = new MediaBot::IRC::Commands::Object;
    $co->type($type);
    $co->ident( $user->ident );
    $co->host( $user->host );
    $co->cmd( $user->host );
    $co->cmd_parameters($args);
    $co->parse_parameters(@_);
    my $mod = $s->Plugins->plugins->{ $s->Plugins->cmd->{$cmd} };
    $mod->$cmd($co);
    return 0;
}

1;
