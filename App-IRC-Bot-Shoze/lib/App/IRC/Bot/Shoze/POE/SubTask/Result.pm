package App::IRC::Bot::Shoze::POE::SubTask::Result;

=head1 NAME

App::IRC::Bot::Shoze::POE::SubTask::Result - SubTask Result

=cut

=head1 SYNOPSIS

=cut

use strict;
use warnings;

use Carp;

use lib qw(../../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY);
use App::IRC::Bot::Shoze::Constants;
use App::IRC::Bot::Shoze::Log;

use Data::Dumper qw(Dumper);

our %fields = (
    event   => undef,
    name    => undef,
    program => undef,
    args    => undef,
    who     => undef,
    where   => undef,
    data    => undef,
    status  => undef,
    session_id => undef,
);

=head1 SUBROUTINES/METHODS

=over

=item new

=cut

sub new {
    my ($proto) = @_;
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    return $s;
}

=item is_valid_program

=cut

sub is_valid_program {
    my $s = shift;
    unless(-x $s->program) {
        WARN("Programe '".$s->program."' is not executable (check path&permission");
        return 0;
    }
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
