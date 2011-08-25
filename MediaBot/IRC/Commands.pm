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
    my $User = shift;
    my $type = shift;

    my $cmd_prefix = $s->cmd_prefix;
    return unless $_[ARG2] =~ /^$cmd_prefix[a-z0-9_-]+/;

    my $args = substr( $_[ARG2], 1 );
    $args =~ s/^([a-zA-Z0-9_-]+)\s*(.*)\s*$/$2/;
    my $cmd = $1;
    LOG("Dispatching command: '$cmd' ($args)");
    unless ( $s->Plugins->exists($cmd) ) {
        print "Unknown command '$cmd\n";
        return 3;
    }
    my $co = new MediaBot::IRC::Commands::Object;
    $co->type($type);
    $co->User($User);
    $co->cmd( $cmd);
    $co->cmd_parameters($args);
    $co->args(\@_);
    my $mod = $s->Plugins->plugins->{ $s->Plugins->cmd->{$cmd} };
    $mod->$cmd($co);
    return 0;
}

1;
