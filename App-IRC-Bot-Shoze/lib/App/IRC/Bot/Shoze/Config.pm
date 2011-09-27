package App::IRC::Bot::Shoze::Config;

=head1 NAME

App::IRC::Bot::Shoze::Config - Loading configuration file

=cut

=head1 SYNOPSIS

   my $C = new App::IRC::Bot::Shoze::Config('/etc/shoze');
   
   ...
   
   Returning singleton object that permit to access YAML
   configuration file.

=cut

use strict;
use warnings;

use Carp;

use YAML qw(LoadFile Dump);
use Data::Dumper qw(Dumper);

use lib qw(../../../../);
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
    _plugins    => undef,
);

=head1 SUBROUTINES/METHODS

=over

=item new


Return singleton object that permit to access configuration file.

parameter: path - The base path for configuration file

=cut

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
    $s->_plugins({});
    #$s->_parent($parent);
    $s->_base_path($path);
    $Singleton = $s;
    return $Singleton;
}

=item load_all

Load all configuration file

=cut

sub load_all {
    my $s = shift;
    for my $k ( keys %{ $s->{_permitted} } ) {
        next if $k =~ /^_/;
        $s->read($k);
    }
}

=item load_plugin

Load plugin specific configuration file (NOT FUNCTIONAL :p)

=cut

sub load_plugin {
    my ($s, $name) = shift;
    croak "Invalid plugin name '$name'" 
        unless $name =~ /^[\w\d]+$/;
    my $file = $s->_base_path . $s->_path . "plugins/$name.yaml";
    unless(-e $file) {
        warn("No configuration found for plugin named '$name'");
        return undef;
    }
    my $y = LoadFile($file);
    unless($y) {
        warn("Cannot parse yaml file '$file'");
        return undef;
    }
    $s->_plugins->{$name} = $y;
    return $s->_plugins->{$name};
}

=item read

Reading one YAML configuration file

parameter:
 
name - Read a YAML configuration file named 'name' located in $path/etc

=cut

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

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2011 Joachim Basmaison.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;
