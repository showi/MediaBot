package App::IRC::Bot::Shoze::POE::IRC::BotCmdPlus::Plugins::ChannelAutoUserMode;

=head1 NAME

App::IRC::Bot::Shoze::Db::ChannelAutoUserMode - ChannelAutoUserMode plugin

=cut

=head1 SYNOPSIS

=cut

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
  qw(_register_cmd _unregister_cmd get_cmd _n_error splitchannel);

our %fields = ( cmd => undef, _parent => undef );

=head1 SUBROUTINES/METHODS

=over

=item new

=cut

sub new {
    my ( $proto, $parent ) = @_;
    my $class = ref($proto) || $proto;
    my $s = {
              _permitted => \%fields,
              %fields,
    };

    bless( $s, $class );
    $s->_parent($parent);
    return $s;
}

=item PCI_register

=cut

sub PCI_register {
    my ( $s, $irc ) = splice @_, 0, 2;
    $irc->plugin_register( $s, 'SERVER', qw(join) );
    return 1;
}

=item PCI_unregister

=cut

sub PCI_unregister {
    my ( $s, $irc ) = splice @_, 0, 2;
    return 1;
}

=item S_join

=cut

sub S_join {
    my ( $s, $irc ) = splice @_, 0, 2;
    my ( $who, $channel ) = ( ${ $_[0] }, ${ $_[1] } );
    my $db = App::IRC::Bot::Shoze::Db->new;

    my ( $nick, $user, $hostname ) = parse_user($who);
    my ( $type, $channame ) = splitchannel($channel);
    my $Channel = $db->NetworkChannels->get_by( $irc->{Network},
                                         { type => $type, name => $channame } );
    unless ($Channel) {
        LOG("We are not managing channel '$channel'");
        return PCI_EAT_NONE;
    }
    print "Chanel: " . $Channel->id . "\n";
    my @GAutoMode =
      $db->ChannelAutoUserMode->list_by( { channel_id => undef } );
    my @LAutoMode =
      $db->ChannelAutoUserMode->list_by( { channel_id => $Channel->id } );
    my @AutoMode = ( @LAutoMode, @GAutoMode );
    for (@AutoMode) {
        print "automode: channel_id: "
          . $_->channel_id . " / "
          . $_->hostmask . " / "
          . $who . "\n";
        if ( matches_mask( $_->hostmask, $who ) ) {
            LOG( "AutoMode match hostmask '" . $_->hostmask . "'" );
            if ( $_->mode eq 'o' ) {
                LOG("Need to op $who");
                $irc->yield( 'mode' => "$channel +o $nick" );
                last;
            } elsif ( $_->mode eq 'v' ) {
                LOG("Need to voice $who");
                $irc->yield( 'mode' => "$channel +v $nick" );
                last;
            } elsif ( $_->mode eq 'b' ) {
                LOG("Need to ban $who");
            } else {
                WARN( "Invalid AutoMode '" . $_->action . "'" );
            }
        }
    }
    return PCI_EAT_NONE;
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
