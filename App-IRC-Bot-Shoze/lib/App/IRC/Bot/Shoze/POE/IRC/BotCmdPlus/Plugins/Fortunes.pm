package App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::Fortunes;

use strict;
use warnings;

use Carp;
use Encode qw(encode decode);
use Data::Dumper;
use YAML qw(Dump thaw);

use POE::Component::IRC::Plugin qw(:ALL);
use IRC::Utils qw(:ALL);

use lib qw(../../../../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::String;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Helper
  qw(_register_cmd _unregister_cmd get_cmd _n_error _send_lines _send_lines_privmsg);
use App::IRC::Bot::Shoze::POE::SubTask::Request;

our %fields = ( cmd => undef, _parent => undef, program => undef );

sub new {
    my ( $proto, $parent ) = @_;
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };

    bless( $s, $class );
    $s->_parent($parent);
    my $program = "/usr/games/fortune";
    unless ( -x $program ) {
        die "Error: $program not found or not executable";
    }
    $s->program($program);
    $s->cmd(
        {
            'fortune' => {
                access           => 'public',
                lvl              => 0,
                help_cmd         => '!fortune',
                help_description => '',
            },
        }
    );
    return $s;
}

sub PCI_register {
    my ( $s, $irc ) = splice @_, 0, 2;
    $irc->plugin_register( $s, 'SERVER', qw(tld_result) );
    $s->_register_cmd($irc);
    return 1;
}

sub PCI_unregister {
    my ( $s, $irc ) = splice @_, 0, 2;
    $s->_unregister_cmd($irc);
    return 1;
}

sub fortune {
    my ( $s, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'fortune';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = App::IRC::Bot::Shoze::Db->new;

    my ( $nick, $user, $hostmask ) = parse_user($who);
    my $cmd = $s->program;
    my $res = `$cmd`;
    $res = str_chomp($res);
    $res = $res;
    $s->_send_lines( $irc, 'privmsg', '#me#', $where, split(/\n/, $res));
    return PCI_EAT_ALL;
}

1;
