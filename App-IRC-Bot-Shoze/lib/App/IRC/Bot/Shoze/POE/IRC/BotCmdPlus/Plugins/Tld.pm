package App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::Tld;

use strict;
use warnings;

use Carp;
use Encode qw(encode decode);
use Data::Dumper;

use POE::Component::IRC::Plugin qw(:ALL);
use IRC::Utils qw(:ALL);

use lib qw(../../../../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::String;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Helper
  qw(_register_cmd _unregister_cmd get_cmd _n_error);

our %fields = ( cmd => undef, _parent => undef );

sub new {
    my ( $proto, $parent ) = @_;
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };

    bless( $s, $class );
    $s->_parent($parent);
    my $program = $s->_get_root->_path . "/scripts/tld.pl";
    unless ( -x $program ) {
        die "Error: $program not found or not executable";
    }
    $s->cmd(
        {
            'tld' => {
                access           => 'public',
                lvl              => 0,
                help_cmd         => '!tld <tld>',
                help_description => 'Give ue tld',
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

sub S_tld_result {
    my ( $s, $irc ) = splice @_, 0, 2;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my ( $nick, $user, $hostmask ) = parse_user($who);
    my ( $status, $otld, $atld, $type, $info ) = split /#/, $msg;
    LOG("EVENT[tld_result] $nick request tld $atld on channel $where!");
    if ( $status < 0 ) {
        $s->_n_error( $irc, $where,
            "Error: Script is missing or not executable" );
    }
    if ($status) {
        $irc->yield( 'privmsg' => $where =>
              "Error: no match for tld $atld ($otld), $type" );
        return PCI_EAT_ALL;
    }
    my $str = "$type $atld ($otld)";
    $str .= ": " . $info if $info;
    $irc->yield( 'privmsg' => $where => $str );
    return PCI_EAT_ALL;
}

sub tld {
    my ( $s, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'tld';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = App::IRC::Bot::Shoze::Db->new;

    my ( $nick, $user, $hostmask ) = parse_user($who);

    LOG("Wanna some tld ????");
    my $cmd;
    ( $cmd, $msg ) = split( /\s+/, str_chomp($msg) );
    my $SubTask = App::IRC::Bot::Shoze->new->POE->SubTask;
    my $data    = {
        event   => "irc_tld_result",
        name    => "tld",
        program => $s->_get_root->_path . "/scripts/tld.pl",
        args    => $msg,
        who     => $who,
        where   => $where->[0],
    };
    $SubTask->add_task($data);
    return PCI_EAT_ALL;
}

1;
