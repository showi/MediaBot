package App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::EasySentence;

use strict;
use warnings;

use Carp;

use POE::Component::IRC::Plugin qw(:ALL);
use IRC::Utils qw(:ALL);
use Encode qw(encode_utf8 encode decode);

use lib qw(../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::String;
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Helper;

our %fields = ( cmd => undef , kind => undef);

sub new {
    my ( $proto, $parent ) = @_;
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    $s->kind({});
    $s->kind->{insulte} = 1;
    $s->cmd(
        {
            'insulte' => {
                access   => 'public',
                lvl      => 0,
                help_cmd => '!insulte',
                help_description => 'No gonna explain this to you, monkey!',
            },
            'carambar' => {
                access   => 'public',
                lvl      => 0,
                help_cmd => '!carambar',
                help_description => "Oh no that's not funny @#!",
            },
            'proverbe' => {
                access   => 'public',
                lvl      => 0,
                help_cmd => '!proverbe',
                help_description => "Be smarter everyday... or not!",
            },
        }
    );
    return $s;
}

sub insulte {
    my ( $self, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'insulte';
    my $PCMD    = $self->get_cmd($cmdname);
    my $db      = $irc->{database};

    my @list = $db->Sentences->list('insulte');
    unless(@list) {
        LOG("No insult in database!");
        return PCI_EAT_ALL;
    }
    my $rand = rand(@list);
    #my $str = decode('utf8', $list[$rand]->text);
    my $str = $list[$rand]->text;
    LOG("[$who] $where/Insulte: $str");
     my @lines = split(/\n/, $str);
    $self->_send_lines($irc, 'privmsg', $where, @lines);
    return PCI_EAT_ALL;
}

sub carambar {
    my ( $self, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'carambar';
    my $PCMD    = $self->get_cmd($cmdname);
    my $db      = $irc->{database};

    my @list = $db->Sentences->list('carambar');
    unless(@list) {
        LOG("No carambar in database!");
        return PCI_EAT_ALL;
    }
    my $rand = rand(@list);
    my $str = "<< " . $list[$rand]->text . " >>";
    $str .= "\n[" . $list[$rand]->author . "]" 
        if $list[$rand]->author;
    #$str = decode('utf8', $str);
    LOG("[$who] $where/Carambar: $str");
    my @lines = split(/\n/, $str);
    $self->_send_lines($irc, 'privmsg', $where, @lines);
    return PCI_EAT_ALL;
}

sub proverbe {
    my ( $self, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'proverbe';
    my $PCMD    = $self->get_cmd($cmdname);
    my $db      = $irc->{database};

    my @list = $db->Sentences->list('proverbe');
    unless(@list) {
        LOG("No proverbe in database!");
        return PCI_EAT_ALL;
    }
    my $rand = rand(@list);
    my $str = "<< " . $list[$rand]->text . " >>";
    $str .= "\n[" . $list[$rand]->author . "]" 
        if $list[$rand]->author;
    #$str = decode('utf8', $str);
    LOG("[$who] $where/Proverbe: $str");
    my @lines = split(/\n/, $str);
    $self->_send_lines($irc, 'privmsg', $where, @lines);
    return PCI_EAT_ALL;
}


1;
