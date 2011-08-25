package MediaBot::Constants;

use strict;
use warnings;

use Carp;
use Exporter;

use constant {
    IRCCMD_TYPE_PRV => 0,
    IRCCMD_TYPE_PUB => 1,
};

our @ISA    = qw(Exporter);
our @EXPORT = qw(IRCCMD_TYPE_PRV IRCCMD_TYPE_PUB);

1;
