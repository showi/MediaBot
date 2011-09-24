package App::IRC::Bot::Shoze::POE::SubTask::Result;

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
);

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

sub is_valid_program {
    my $s = shift;
    unless(-x $s->program) {
        WARN("Programe '".$s->program."' is not executable (check path&permission");
        return 0;
    }
}

1;