package App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::Apero;

use strict;
use warnings;

use Carp;

use POE::Component::IRC::Plugin qw(:ALL);
use IRC::Utils qw(:ALL);

use lib qw(../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::String;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Helper qw(:ALL);

our %fields = ( cmd => undef );

sub new {
    my ( $proto, $parent ) = @_;
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    $s->cmd(
        {
#            'apero_add' => {
#                access   => 'msg',
#                lvl      => 800,
#                help_cmd => '!apero.add <name> <trigger>',
#                help_description => 'Add a new apero',
#            },
#            'apero_del' => {
#                access   => 'msg',
#                lvl      => 800,
#                help_cmd => '!apero.del <name>',
#                help_description => 'Deleting a give apero',
#            },
#            'apero_list' => {
#                access   => 'msg',
#                lvl      => 800,
#                help_cmd => '!apero.list',
#                help_description => 'List apero',
#            },
#            'apero_set' => {
#                access           => 'msg',
#                lvl              => 800,
#                help_cmd         => '!apero.set <name> <trigger> <value>',
#                help_description => 'Setting trigger for apero (require reloading)',
#            },
#            'apero_set_text' => {
#                access           => 'msg',
#                lvl              => 800,
#                help_cmd         => '!apero.set.text <name> <index> <text>',
#                help_description => 'Setting text at index',
#            },
#            'apero_set_chantext' => {
#                access           => 'msg',
#                lvl              => 800,
#                help_cmd         => '!apero.set.chantext <name> <index> <text>',
#                help_description => 'Setting channel text at index',
#            },
#            'apero_info' => {
#                access           => 'msg',
#                lvl              => 800,
#                help_cmd         => '!apero.info <name>',
#                help_description => 'Information about a given apero',
#            },
        }
    );
    return $s;
}

1;
