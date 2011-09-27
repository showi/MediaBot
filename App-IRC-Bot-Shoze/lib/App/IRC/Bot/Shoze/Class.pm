package App::IRC::Bot::Shoze::Class;

=head1 NAME

App::IRC::Bot::Shoze::Class - Methods inerithed by most of our object

=cut

=head1 SYNOPSIS

    Class package provides AUTOLOAD method that must of our object use. 
    This permit 00 access on fiels authorized in $self->permitted.
    AUTOLOAD and DESTROY methods are exported by default

=cut

use strict;
use warnings;
use Carp;

use Exporter;

use lib qw(../../../../);
use App::IRC::Bot::Shoze::Log;

=head1 EXPORT

=over

=item AUTOLOAD

=item DESTROY

=back

=cut

our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(AUTOLOAD DESTROY _print);
our @EXPORT    = qw(_get_root);

=head1 SUBROUTINES/METHODS

=over

=item AUTOLOAD

When undefined methods are called on object AUTOLOAD watch for permitted method in $self->{_permitted}

=cut
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
    } else {
        return $self->{$name};
    }
}

=item DESTROY

Just printing object name when they disappear

=cut

sub DESTROY {
    my $s = shift;
    DEBUG( "- Detroying object " . ref($s), 6 ) if ref($s);
}

=item _get_root (deprecated)

This method is following $self->_parent and stop when top 
parent is found.

=cut

sub _get_root {
    my ($s) = shift;
    return $s unless defined $s->{_parent};
    return $s->_parent->_get_root();
}

=item _print

Nicely print object properties

=cut

sub _print {
    my ($s)  = shift;
    my $SEP  = '-' x 80 . "\n";
    my $DSEP = '-' x 80 . "\n";
    my $str  = $s->__PACKAGE__ . "\n";
    $str .= $DSEP;
    for my $k ( keys %{ $s->{permitted} } ) {
        $str .= "$k: " . $s->$k . "\n";
    }
    return $str;
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
