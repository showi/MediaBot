package App::IRC::Bot::Shoze::POE::IRC::Out;

=head1 NAME

App::IRC::Bot::Shoze::POE::IRC::Out - IRC bot output 

=cut

=head1 SYNOPSIS

=cut

use strict;
use warnings;

use Carp;

use POE;

use IRC::Utils ':ALL';

use lib qw(../../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD _get_root DESTROY);
use App::IRC::Bot::Shoze::Constants qw(:ALL);
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::Db;

use Data::Dumper qw(Dumper);

our %fields = ( _parent => undef, _irc => undef );

=head1 SUBROUTINES/METHODS

=over

=item new

=cut

sub new {
    my ( $proto, $parent, $irc ) = @_;
    croak "No parent object passed as first parameter"
      unless ref($parent);
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    $s->_parent($parent);
    $s->_irc($irc);
    return $s;
}


=item send_msg

=cut

sub send_msg {
    my ($s, $type, $who, $target, $msg) = @_;
    my $dest = $target;
    $s->log( $type, $who, $target, $msg );
    if (ref($target) =~ /NetworkSessions/) {
        LOG("NetworkSessions object");
        if ($target->user_id and $target->user_lvl >= 800) {
            $s->_irc->call( $type => $target->nick => $msg );
            return;
        } 
        $dest = $target->nick;
    }
    $s->_irc->yield( $type => $dest => $msg );
}

=item notice

=cut

sub notice {
    my ( $s, $who, $target, $msg ) = @_;
    $s->send_msg('notice', $who, $target, $msg);
    #$s->_irc->yield( notice => $target => $msg );
}

=item privmsg

=cut

sub privmsg {
    my ( $s, $who, $target, $msg ) = @_;
    $s->send_msg('privmsg', $who, $target, $msg);
#    $s->log( 'privmsg', $who, $target, $msg );
#    $s->_irc->yield( privmsg => $target => $msg );
}

=item ctcp_action

=cut

sub ctcp_action {
    my ( $s, $who, $target, $msg ) = @_;
    #$s->send_msg('notice', $who, $target, $msg);
    $s->log( 'ctcp_action', $who, $target, $msg );
    $s->_irc->yield( ctcp => $target => "ACTION $msg" );
}

=item log

=cut

sub log {
    my ( $s, $type, $who, $target, $msg ) = @_;
    my $db = App::IRC::Bot::Shoze::Db->new;
    my @T;
    if ( ref($target) =~ /^ARRAY/ ) {
        @T = @{$target};
    }
    else {
        push @T, $target;
    }
    my $time = time;
    for (@T) {
        $db->BotLogs->create( $s->_irc->{Network}->id, $type, $who, $_, $msg )
          ;
         # $s->_irc->call( privmsg => "#teuk" => "[$time][$type][$_][$who] $msg" );
    }
}

=item join

=cut

sub join {
    my ( $s, $who, $where, $Channel ) = @_;
    my $msg = $Channel->_usable_name;
    $msg .= ' ' . $Channel->password if $Channel->password;
    $s->log( 'join', $who, $where, $Channel->_usable_name );
    $s->_irc->yield( join => $msg );
}

=item part

=cut

sub part {
    my ( $s, $who, $where, $Channel ) = @_;
    my $msg = $Channel->_usable_name;
    $s->log( 'part', $who, $where, $Channel->_usable_name );
    $s->_irc->yield( part => $Channel->_usable_name );
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
