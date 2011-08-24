package MediaBot::IRC::Commands::Plugins;
use strict;
use warnings;

use Carp;
use Exporter;

use lib qw(../../../);
use MediaBot::Class qw(AUTOLOAD DESTROY LOG _get_root);
use MediaBot::String;

our $AUTOLOAD;

our %fields = ( 
    _parent => undef,
);

# Constructor
#############
sub new {
    my ( $proto, $parent ) = @_;
    print "Creating new " . __PACKAGE__ . "\n";
    croak "No parent specified" unless ref $parent;
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    $s->_parent($parent);
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
    if (defined $s->{$name}) {
        print "Plugin with same name present ($name)!";
        return 1;
    }
    $s->{_permitted}->{$name} = 1;
    my $pname = "MediaBot::IRC::Commands::Plugins::".ucfirst($name);
    eval "require $pname";
    $s->$name($pname->new($s));
    $s->$name->lvl($h->{lvl});
    $s->$name->description($h->{description});
    $s->$name->on($h->{on});
    print "Plugin $pname loaded\n";
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
