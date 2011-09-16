package App::IRC::Bot::Shoze::POE::IRC::Apero;

use strict;
use warnings;

use Carp;
use POE;
use POE::Component::IRC::Plugin qw(:ALL);
use IRC::Utils qw(:ALL);
use Encode qw(encode_utf8 encode decode);
use Unicode::Normalize;

use lib qw(../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY);
use App::IRC::Bot::Shoze::Constants;
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::String;

use Data::Dumper qw(Dumper);

our %fields = ( triggers => undef, );

sub new {
    my ($proto) = @_;
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    $s->triggers( {} );
    return $s;
}

sub PCI_register {
    my ( $self, $irc ) = splice @_, 0, 2;
    $irc->plugin_register( $self, 'SERVER', qw(public) );
    my $db = App::IRC::Bot::Shoze::Db->new;
    my @triggers = $db->Apero->list;
    $self->triggers( {} );
    for my $A (@triggers) {
        my $t = $A->trigger;
        DEBUG("Registering trigger $t", 6);
        $self->triggers->{ $A->id } = qr/$t/i;
    }
    return 1;
}

sub PCI_unregister {
    my ($self) = @_;
    delete $self->{triggers};
    return 1;
}

sub _have_trigger {
    my ( $s, $db, $cmd ) = @_;
    #print "Searching for match for cmd '$cmd'\n";
    for my $id ( keys %{ $s->triggers } ) {
        my $t = $s->triggers->{$id};
        #print "Looking id: $id ($t)\n";
        if ( $cmd =~ /$t/i ) {
        #    print "Get a match with id: $id\n";
            return $db->Apero->get($id);
        }
    }

}

sub S_public {
    my ( $self, $irc ) = splice @_, 0, 2;
    my ( $who, $where, $msg ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my $db = App::IRC::Bot::Shoze::Db->new;
    my ( $nick, $name, $hostmask ) = parse_user($who);

    my $prefix = substr $msg, 0, 1;
    if ( $prefix ne '!' ) {
        return PCI_EAT_NONE;
    }
    $msg = substr $msg, 1;
    my @params = split( /\s+/, str_chomp($msg) );
    my $cmd = shift @params;
    $cmd = NFKD( decode( "utf-8", $cmd ) );
    my $ocmd = $cmd;
    $cmd =~ s/\pM//g;

    my $A = $self->_have_trigger( $db, $cmd );
    return PCI_EAT_NONE unless $A;

    #print "Got trigger for $params[0]\n";
    #print $A->text . "\n";
    my @target = @params;
    my $type   = 'user';
    #print "Num Arg:" . $#params . "\n";
    if ( $#params == 0 ) {
        $type = 'chan' if grep /^#[^\s]+$/, $params[0];
    }
    elsif ( $#params > 0 ) {
        $type = 'users';
    }
    else {
        push @target, $nick;
    }

    my $str;
    my @choices;
    if ( $type eq 'chan' ) {
        if ( $A->chantext ) {
            @choices = split( /\|/, $A->chantext );
        }
        else {
            @choices = split( /\|/, $A->text );
        }
    }
    else {
        @choices = split( /\|/, $A->text );
    }
    #print "Choice0: " . $choices[0] . "\n";
    $str = $choices[ int( rand( $#choices + 1 ) ) ];
    #print "Str before: $str\n";
    if ( $type eq 'users' ) {
        my $people;
        my $be = $#target - 1;
        for ( 0 .. $be ) {
            $people .= $target[$_];
            $people .= ", " unless $_ == $be;
        }
        $people .= " et " . $target[ $be + 1 ];
        $str =~ s/%WHO%/$people/g;
    }
    else {
        my $one = $target[0];
        $str =~ s/%WHO%/$one/g;
    }
    #print "type: $type\n";
    $str =~ s/%NICK%/$nick/g;
    $str =~ s/%CMD%/$ocmd/g;
    $str =~ /%IRAND(\d+)%/ and do {
        my $rand = int(rand($1)) + 1;
        $str =~ s/%IRAND(\d{})%/$rand/g; # .  
    };
    $str = decode('utf8', $str);
    if ($A->msg_type) {
        if ($A->msg_type eq "action") {
            $irc->yield(ctcp => $where => "ACTION $str");
        } else {
            WARN("Apero id: " . $A->id ." unknown msg_type '".$A->msg_type."'");
            $irc->yield( privmsg => $where => $str );
        }
    } else {
        $irc->yield( privmsg => $where => $str );
    }
    return PCI_EAT_ALL;
}

1;
