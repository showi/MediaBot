package MediaBot::Class;
use strict;
use warnings;
use Carp;

use lib qw(..);
use Exporter;

use MediaBot::Log;

our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(AUTOLOAD DESTROY);
our @EXPORT    = qw(_get_root);

our $AUTOLOAD;

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self)
      or croak "$self is not an object";
    my $name = $AUTOLOAD;
    $name =~ s/.*://;        # strip fully-qualified portion
    #print "ERROR: $name\n";
    unless ( exists $self->{_permitted}->{$name} ) {
        croak "Can't access `$name' field in class $type";
    }
    if (@_) {
        return $self->{$name} = shift;
    }
    else {
        return $self->{$name};
    }
}

sub DESTROY {
    my $s = shift;
    DEBUG( "- Detroying object " . ref($s), 5) if ref($s);
}

sub _get_root {
    my ($s) = shift;
    return $s unless defined $s->{_parent};
    return $s->_parent->_get_root();
}

1;
