package MediaBot::IRC::Commands::Plugins;
use strict;
use warnings;

use Carp;
use Exporter;

use Data::Dumper;

use lib qw(../../../);
use MediaBot::Class qw(AUTOLOAD DESTROY _get_root);
use MediaBot::String;
use MediaBot::Log;

our $AUTOLOAD;

our %fields = ( 
    _parent => undef,
    cmd => undef,
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
    $s->cmd({});
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
    DEBUG($plugin->registered_cmd);
    for(@{$plugin->registered_cmd}) {
        croak "Command $_ already registerd by plugin " . $s->cmd->{$_} 
            if defined $s->cmd->{$_};
        LOG("Plugin $name registering command: $_");
        $s->cmd->{$_} = $name;
    }
    print Dumper $s;
    #exit 0;
    return 0;
}

sub exists {
    my ($s, $name) = @_;
   return 1 if $s->{cmd}->{$name};
   return 0; 
}

sub unload {
  my ($s, $name) = @_;  
    
}

1;
