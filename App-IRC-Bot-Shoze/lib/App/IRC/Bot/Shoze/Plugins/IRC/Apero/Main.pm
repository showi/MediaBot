package App::IRC::Bot::Shoze::Plugins::IRC::Apero::Main;

=head1 NAME

App::IRC::Bot::Shoze::POE::IRC::Apero - Apero plugin 

=cut

=head1 SYNOPSIS

=cut

use strict;
use warnings;

use Carp;
use POE;
use POE::Component::IRC::Plugin qw(:ALL);
use IRC::Utils qw(:ALL);
use Encode qw(encode_utf8 encode decode);
use Unicode::Normalize;

use lib qw(../../../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY);
use App::IRC::Bot::Shoze::Constants;
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::String;

use Data::Dumper qw(Dumper);

our %fields = ( triggers => undef, );

=head1 SUBROUTINES/METHODS

=over

=item new

=cut

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

=item PCI_register

=cut

sub PCI_register {
    my ( $self, $irc ) = splice @_, 0, 2;
    $irc->plugin_register( $self, 'SERVER', qw(public) );
    my $db       = App::IRC::Bot::Shoze::Db->new;
    $db->Plugins->load('IRC', 'Apero');
    my @triggers = $db->Plugins->Apero->list;
    $self->triggers( {} );
    for my $A (@triggers) {
        my $t = $A->trigger;
        DEBUG( "Registering trigger $t", 8 );
        $self->triggers->{ $A->id } = qr/$t/i;
    }
    return 1;
}

=item PCI_unregister

=cut

sub PCI_unregister {
    my ($self) = @_;
    delete $self->{triggers};
    return 1;
}

=item _have_trigger

=cut

sub _have_trigger {
    my ( $s, $db, $cmd ) = @_;
    for my $id ( keys %{ $s->triggers } ) {
        my $t = $s->triggers->{$id};
        if ( $cmd =~ /$t/i ) {
            return $db->Plugins->Apero->get($id);
        }
    }
}

=item S_public

=cut

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
    my @target = @params;
    my $type   = 'user';

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
    $str = $choices[ int( rand( $#choices + 1 ) ) ];
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
    $str =~ s/%NICK%/$nick/g;
    $str =~ s/%CMD%/$ocmd/g;
    $str =~ /%IRAND(\d+)%/ and do {
        my $rand = int( rand($1) ) + 1;
        $str =~ s/%IRAND(\d{})%/$rand/g;    # .
    };
    $str = decode( 'utf8', $str );
    if ( $A->msg_type ) {
        if ( $A->msg_type eq "action" ) {
            $irc->{Out}->ctcp_action( $who, $where, $str );
        }
        else {
            WARN(   "Apero id: "
                  . $A->id
                  . " unknown msg_type '"
                  . $A->msg_type
                  . "'" );
            $irc->{Out}->privmsg( $who, $where, $str );
        }
    }
    else {
        $irc->{Out}->privmsg( $who, $where, $str );
    }
    return PCI_EAT_ALL;
}

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2011 Joachim Basmaison.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;
