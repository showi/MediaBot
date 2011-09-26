package App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::Icecast;

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
  qw(_register_cmd _unregister_cmd get_cmd _n_error);
use App::IRC::Bot::Shoze::POE::SubTask::Request;

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
    my $program = $s->_get_root->_path . "/scripts/icestats.pl";
    unless ( -x $program ) {
        die "Error: $program not found or not executable";
    }
    $s->cmd(
        {
            'listeners' => {
                access           => 'public',
                lvl              => 0,
                help_cmd         => '!listeners <tld>',
                help_description => 'Give radiocapsule listeners',
            },
        }
    );
    return $s;
}

sub PCI_register {
    my ( $s, $irc ) = splice @_, 0, 2;
    $irc->plugin_register( $s, 'SERVER', qw(icecast_listeners_result) );
    $s->_register_cmd($irc);
    return 1;
}

sub PCI_unregister {
    my ( $s, $irc ) = splice @_, 0, 2;
    $s->_unregister_cmd($irc);
    return 1;
}

sub S_icecast_listeners_result {
    my ( $s, $irc ) = splice @_, 0, 2;
    my ( $who, $where, $result ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my ( $nick, $user, $hostmask ) = parse_user($who);
    my $ref = thaw( $result->data );
    if ( $result->status < 0 ) {
        $s->_n_error( $irc, $where,
            "Error: Script is missing or not executable" );
    }
    my $d = $ref->{icestats};
    if ( $result->status ) {
        $irc->privmsg('#me#', $where, "Error: Can't fetch listeners!");
        return PCI_EAT_ALL;
    }

    my $str = $d->{host} . " / " . $d->{listeners} . " listeners";
    $irc->privmsg('#me#', $where, $str );
    return PCI_EAT_ALL;
}

sub listeners {
    my ( $s, $Session, $irc, $event ) = splice @_, 0, 4;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'listeners';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = App::IRC::Bot::Shoze::Db->new;

    my ( $nick, $user, $hostmask ) = parse_user($who);
    my $cmd;
    ( $cmd, $msg ) = split( /\s+/, str_chomp($msg) );
    my $request = new App::IRC::Bot::Shoze::POE::SubTask::Request;
    $request->event('irc_icecast_listeners_result');
    $request->name('icecast');
    $request->program( $s->_get_root->_path . "/scripts/icestats.pl" );
    $request->who($where);
    $request->where( $where->[0] );
    my $SubTask = App::IRC::Bot::Shoze->new->POE->SubTask;
    $SubTask->add_task($request);
    return PCI_EAT_ALL;
}

1;
