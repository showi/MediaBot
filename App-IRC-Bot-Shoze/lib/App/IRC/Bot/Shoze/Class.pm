package App::IRC::Bot::Shoze::Class;
use strict;
use warnings;
use Carp;

use Exporter;

use lib qw(../../../../);
use App::IRC::Bot::Shoze::Log;

our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(AUTOLOAD DESTROY _print);
our @EXPORT    = qw(_get_root);

our $AUTOLOAD;

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self)
      or croak "$self is not an object";
    my $name = $AUTOLOAD;
    $name =~ s/.*://;
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
    DEBUG( "- Detroying object " . ref($s), 6) if ref($s);
}

sub _get_root {
    my ($s) = shift;
    return $s unless defined $s->{_parent};
    return $s->_parent->_get_root();
}

sub _print {
    my ($s) = shift;
    my $SEP = '-'x80 . "\n";
    my $DSEP = '-'x80 . "\n";
    my $str = $s->__PACKAGE__ . "\n";
    $str .= $DSEP;
    for my $k(keys %{$s->{permitted}}) {
        $str .= "$k: " . $s->$k . "\n";
    }
    return $str;
}

1;
