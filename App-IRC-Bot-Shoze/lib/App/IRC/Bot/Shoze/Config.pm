package App::IRC::Bot::Shoze::Config;

use strict;
use warnings;

use Carp;

use YAML qw(LoadFile Dump);
use Data::Dumper qw(Dumper);

use lib qw(..);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY);
use App::IRC::Bot::Shoze::Log;

our $AUTOLOAD;

our $Singleton = undef;

my %fields = (
   # _parent    => undef,
    _base_path => undef,
    _path      => 'etc/',
    irc        => undef,
    db         => undef,
    bot        => undef,
    ws         => undef,
);

sub new {
    my ( $proto, $path ) = @_;
    if ( defined $Singleton ) {
        return $Singleton;
    }
    DEBUG( "Creating new " . __PACKAGE__, 6);
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    #$s->_parent($parent);
    $s->_base_path($path);
    $s->load_all();
    $Singleton = $s;
    return $Singleton;
}

sub load_all {
    my $s = shift;
    for my $k ( keys %{ $s->{_permitted} } ) {
        next if $k =~ /^_/;
        $s->read($k);
    }
}

sub read {
    my ( $s, $name ) = @_;
    croak "No configuration name specified" unless $name;
    croak "Invalid configuration name '$name'"
      if $name =~ /^_.*$/
          or !grep( $name, keys %{ $s->{_permitted} } );
    my $f = $s->_base_path . $s->_path . "$name.yaml";
    croak "Configuration file not found '$f'"
      unless -e $f;
    my $y = LoadFile($f);
    croak "Cannot load configuration file '$f' ($!)"
      unless defined $y;
    $s->$name($y);
    LOG("Configuration file loaded: $f");
    return 0;
}

1;
