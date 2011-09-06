package App::IRC::Bot::Shoze::Constants;

use strict;
use warnings;

use Carp;
use Exporter;

our @TAGS = qw(
  IRCCMD_TYPE_PRV
  IRCCMD_TYPE_PUB

  BOT_OK
  BOT_NOK

  BOT_CHAN_UNREGISTERED
  BOT_CHAN_ALEARDYJOINED
  BOT_CHAN_NOTACTIVE
  BOT_CHAN_INVALIDNAME
  BOT_CHAN_NOTJOINED
  
  BOT_USER_ACCESSDENIED
);
our @ISA         = qw(Exporter);
our @EXPORT      = @TAGS;
our %EXPORT_TAGS = ( ALL => [@TAGS] );

use constant {
    IRCCMD_TYPE_PRV => 0,
    IRCCMD_TYPE_PUB => 1,

    BOT_OK                 => 0,
    BOT_NOK                => 1,
    BOT_CHAN_UNREGISTERED  => 2,
    BOT_CHAN_ALEARDYJOINED => 3,
    BOT_CHAN_NOTACTIVE     => 4,
    BOT_CHAN_INVALIDNAME   => 5,
    BOT_CHAN_NOTJOINED     => 5,

    BOT_USER_ACCESSDENIED => 100,
};

1;
