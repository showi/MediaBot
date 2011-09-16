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
use App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Helper qw(:ALL);
use App::IRC::Bot::Shoze::Db::EasySentence::Object;

our %fields =
  ( cmd => undef, kind => undef, _parent => undef, authtypes => undef, );

###############################################################################
sub new {
    my ( $proto, $parent ) = @_;
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    $s->_parent($parent);
    $s->kind( {} );
    $s->kind->{insulte} = 1;
    my @auth = qw(proverbe insulte carambar);
    $s->authtypes( \@auth );
    $s->cmd(
        {
            'insulte' => {
                access           => 'public',
                lvl              => 0,
                help_cmd         => '!insulte',
                help_description => 'No gonna explain this to you, monkey!',
            },
            'carambar' => {
                access           => 'public',
                lvl              => 0,
                help_cmd         => '!carambar',
                help_description => "Oh no that's not funny @#!",
            },
            'proverbe' => {
                access           => 'public',
                lvl              => 0,
                help_cmd         => '!proverbe',
                help_description => "Be smarter everyday... or not!",
            },
            'sentence_add' => {
                access           => 'msg',
                lvl              => 400,
                help_cmd         => '!sentence.add <type> <sentence [author]>',
                help_description => "Add a sentence",
            },
            'sentence_list' => {
                access           => 'msg',
                lvl              => 400,
                help_cmd         => '!sentence.list <pattern>',
                help_description => "List",
            },
        }
    );
    return $s;
}

###############################################################################
sub sentence_add {
    my ( $s, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'sentence_add';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = App::IRC::Bot::Shoze::Db->new;

    $msg = str_chomp($msg);
    my ( $cmd, $type, @sentauthor ) = split( /\s+/, $msg );

    unless ( grep ( /$type/, @{ $s->authtypes } ) && @sentauthor ) {
        return $s->_n_error( $irc, $Session->nick,
            "Invalid sentence type 'type', must be proverbe|insulte|carambar" );
    }
    my $sentence = join( ' ', @sentauthor );
    $sentence = str_chomp($sentence);
    my $author;
    $sentence =~ s/(\[#(.*)#\])// and do {
        $author = $2;
    };
    LOG("$cmdname: $sentence / $author");
    my $Sentence = $db->Sentences->get_by( $type, { text => $sentence } );
    if ($Sentence) {
        return $s->_n_error( $irc, $Session->nick,
            "This '$type' sentence is already in database!" );
    }
    my $A = new App::IRC::Bot::Shoze::Db::EasySentence::Object( $db, $type );
    $A->text($sentence);
    $A->author($author) if $author;
    unless ( $A->_create ) {
        return $s->_n_error( $irc, $Session->nick, "Cannot add this sentence" );
    }
    else {
        $irc->yield( 'notice', $Session->nick,
            "Sentence of type '$type' added:" );
        $irc->yield( 'notice', $Session->nick, "$sentence  >> $author <<" );
    }
    return PCI_EAT_ALL;
}

###############################################################################
sub sentence_list {
    my ( $s, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'sentence_list';
    my $PCMD    = $s->get_cmd($cmdname);
    my $db      = App::IRC::Bot::Shoze::Db->new;

    $msg = str_chomp($msg);
    my ( $cmd, $type, @pattern ) = split /\s+/, $msg;
    my $pattern = join ' ', @pattern;
    LOG("$cmdname: $type @pattern");
    unless ( grep ( /$type/, @{ $s->authtypes } ) ) {
        return $s->_n_error( $irc, $Session->nick,
            "Invalid sentence type 'type', must be proverbe|insulte|carambar" );
    }
    my @list;
    if ($pattern) {
        @list = $db->Sentences->list_match( $type, { text => $pattern } );
    }
    else {
        @list = $db->Sentences->list($type);
    }
    my $str = "Listing '$type' sentences:\n";
    for (@list) {
        $str .= '[' . $_->id . '] ';
        $str .= '<<' . $_->author . '>>  ' if $_->author;
        $str .= $_->text . "\n";
    }
    $s->_send_lines( $irc, 'notice', $Session->nick, split( /\n/, $str ) );
    return PCI_EAT_ALL;
}

###############################################################################
sub insulte {
    my ( $self, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'insulte';
    my $PCMD    = $self->get_cmd($cmdname);
    my $db      = App::IRC::Bot::Shoze::Db->new;

    my @list = $db->Sentences->list('insulte');
    unless (@list) {
        LOG("No insult in database!");
        return PCI_EAT_ALL;
    }
    my $rand = rand(@list);
    my $str = decode( 'utf8', $list[$rand]->text );

    #my $str = $list[$rand]->text;
    LOG("[$who] $where/Insulte: $str");
    my @lines = split( /\n/, $str );
    $self->_send_lines( $irc, 'privmsg', $where, @lines );
    return PCI_EAT_ALL;
}

###############################################################################
sub carambar {
    my ( $self, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'carambar';
    my $PCMD    = $self->get_cmd($cmdname);
    my $db      = App::IRC::Bot::Shoze::Db->new;

    my @list = $db->Sentences->list('carambar');
    unless (@list) {
        LOG("No carambar in database!");
        return PCI_EAT_ALL;
    }
    my $rand = rand(@list);
    my $str  = "<< " . $list[$rand]->text . " >>";
    $str .= "\n[" . $list[$rand]->author . "]"
      if $list[$rand]->author;
    $str = decode( 'utf8', $str );
    LOG("[$who] $where/Carambar: $str");
    my @lines = split( /\n/, $str );
    $self->_send_lines( $irc, 'privmsg', $where, @lines );
    return PCI_EAT_ALL;
}

###############################################################################
sub proverbe {
    my ( $self, $Session, $User, $irc, $event ) = splice @_, 0, 5;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $cmdname = 'proverbe';
    my $PCMD    = $self->get_cmd($cmdname);
    my $db      = App::IRC::Bot::Shoze::Db->new;

    my @list = $db->Sentences->list('proverbe');
    unless (@list) {
        LOG("No proverbe in database!");
        return PCI_EAT_ALL;
    }
    my $rand = rand(@list);
    my $str  = "<< " . $list[$rand]->text . " >>";
    $str .= "\n[" . $list[$rand]->author . "]"
      if $list[$rand]->author;
    $str = decode( 'utf8', $str );
    LOG("[$who] $where/Proverbe: $str");
    my @lines = split( /\n/, $str );
    $self->_send_lines( $irc, 'privmsg', $where, @lines );
    return PCI_EAT_ALL;
}

1;
