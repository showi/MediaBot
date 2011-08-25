package MediaBot::IRC::Commands::Plugins;
use strict;
use warnings;

use Carp;
use Exporter;

use lib qw(../../../);
use MediaBot::Class qw(AUTOLOAD DESTROY _get_root);
use MediaBot::String;
use MediaBot::Log;

our $AUTOLOAD;

our %fields = ( 
    _parent => undef,
    cmds => undef,
    plugins => undef,
);

# Constructor
#############
sub new {
    my ( $proto, $parent ) = @_;
    DEBUG("Creating new " . __PACKAGE__);
    croak "No parent specified" unless ref $parent;
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    $s->_parent($parent);
    $s->cmds({});
    $s->plugins({});
    my @plugins = @{$s->_get_root->Config->bot->{cmd_plugins}};
    foreach(@plugins) {
         $s->load($_);
    }
    return $s;
}

sub load {
    my ($s, $h) = @_;  
    my $name = str_chomp($h->{name});
    $name = lc($name);
    LOG(__PACKAGE__." Loading plugin '$name'");
    if (defined $s->plugins->{$name}) {
        print "Plugin with same name present ($name)!";
        return 1;
    }
    $s->{_permitted}->{$name} = 1;
    my $pname = "MediaBot::IRC::Commands::Plugins::".ucfirst($name);
    eval "require $pname";
    my $plugin = $pname->new($s);
    $plugin->lvl($h->{lvl});
    $plugin->description($h->{description});
    $plugin->on($h->{on});
    croak "Plugin with same name already loaded '$name'!" 
        if defined   $s->plugins->{$name};
    $s->plugins->{$name} = $plugin;
    
    print "Plugin $pname loaded\n";
    print "name:  $name\n";
    #"s->plugins->{$name}->{name} . "\n";
    exit;
    return 0;
}

sub exists {
    my ($s, $name) = @_;
   return 1 if $s->{_permitted}->{$name};
   return 0; 
}

sub unload {
  my ($s, $name) = @_;  
    
}

1;
