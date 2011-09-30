package App::IRC::Bot::Shoze::Db::NetworkChannelUsers;

=head1 NAME

App::IRC::Bot::Shoze::Db::NetworkChannelUsers - Methods for easy SQL table access

=cut

=head1 SYNOPSIS
    
Easy SQL table access

=cut

use strict;
use warnings;

use Carp;

use IRC::Utils qw(:ALL);

use lib qw(../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Db::NetworkChannelUsers::Object qw();
use App::IRC::Bot::Shoze::Log;

our $AUTOLOAD;

our %fields = (
    _handle => undef,
    _parent => undef,
);

=head1 SUBROUTINES/METHODS

=over

=item new

=cut

sub new {
    my ( $proto, $parent ) = @_;
    DEBUG( "Creating new " . __PACKAGE__, 8);
    croak "No parent specified" unless ref $parent;
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    $s->_parent($parent);
    return $s;
}

=item get_by

=cut

sub get_by {
    my ( $s, $Channel, $hash ) = @_;
    DEBUG( __PACKAGE__ . "::get_by($hash)", 4 );
    croak "Need Channel object as first parameter "
      unless ref($Channel) =~ /Db::NetworkChannels::Object/;
    $hash->{channel_id} = $Channel->id;
    my $C =
      new App::IRC::Bot::Shoze::Db::NetworkChannelUsers::Object( $s->_parent );
    return $C->_get_by($hash);
}

=item create

=cut

sub create {
    my ( $s, $Channel, $Nick ) = @_;
    croak "Need Channel object as first parameter "
      unless ref($Channel) =~ /Db::NetworkChannels::Object/;
      print ref($Nick) . "\n";
    croak "Need Nick object as second parameter "
      unless ref($Nick) =~ /Db::NetworkNicks::Object/;
    my $time = time;
                        #DEBUG( __PACKAGE__ . "::get_by($hash)", 4);
    my $db = App::IRC::Bot::Shoze::Db->new;
    my $C  = new App::IRC::Bot::Shoze::Db::NetworkChannelUsers::Object($db);
    $C->channel_id( $Channel->id );
    $C->nick_id( $Nick->id );
    return $C->_create;
}

=item list

=cut

sub list {
    my ($s, $Channel) = @_;
    croak "Need Channel object as first parameter "
      unless ref($Channel) =~ /Db::NetworkChannels::Object/;
    my $db = App::IRC::Bot::Shoze::Db->new;
    $db->die_if_not_open();
    my $h     = $db->handle;
    my $query = <<SQL;
SELECT ncu.id AS id, ncu.nick_id AS nick_id, ncu.channel_id AS channel_id, ncu.mode AS mode,
nn.nick AS nick_nick, nc.name AS channel_name,
u.name AS user_name, u.lvl AS user_lvl, u.id AS user_id,
nc.owner AS channel_owner
FROM network_channel_users AS ncu, network_channels AS nc, network_nicks AS nn
LEFT JOIN users AS u ON nc.owner = u.id
WHERE ncu.channel_id = nc.id AND ncu.nick_id = nn.id AND nc.id = ?
SQL
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute($Channel->id)
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    my @list;

    while ( my $r = $sth->fetchrow_hashref ) {
        my $N = new App::IRC::Bot::Shoze::Db::NetworkChannelUsers::Object($db);
        for my $k ( keys %{$N} ) {
            next if $k =~ /^_.*/;
            $N->$k( $r->{$k} );
        }
        my @extf = qw(
          session_nick session_user session_hostname session_id session_ignore
          user_id user_name user_lvl user_pending user_hostmask
          channel_owner
        );
        for (@extf) {
            $N->_add_permitted_field($_);
            $N->$_( $r->{$_} );
        }
        $N->synched;
        push @list, $N;
    }
    return @list;
}

=item is_on

=cut

sub is_on {
     my ($s, $Nick) = @_;
    croak "Need Nick object as first parameter "
      unless ref($Nick) =~ /Db::NetworkNicks::Object/;
    LOG("Listing channels where nick '".$Nick->nick."' is!");
    my $db = App::IRC::Bot::Shoze::Db->new;
    $db->die_if_not_open();
    my $h     = $db->handle;
    my $query = <<SQL;
 SELECT ncu.id AS id, ncu.nick_id AS nick_id, ncu.channel_id AS channel_id, ncu.mode AS mode,
nn.nick AS nick_nick, nc.name AS channel_name,
u.name AS owner_name, nc.owner AS owner_id
FROM network_channel_users AS ncu, network_channels AS nc, network_nicks AS nn
LEFT JOIN users AS u ON nc.owner = u.id
WHERE ncu.channel_id = nc.id AND ncu.nick_id = nn.id AND nn.id = ?
SQL
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute($Nick->id)
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    my @list;

    while ( my $r = $sth->fetchrow_hashref ) {
        my $N = new App::IRC::Bot::Shoze::Db::NetworkChannelUsers::Object($db);
        for my $k ( keys %{$N} ) {
            next if $k =~ /^_.*/;
            $N->$k( $r->{$k} );
        }
        my @extf = qw(
        nick_nick nick_id channel_name owner_name owner_id
        );
        for (@extf) {
            $N->_add_permitted_field($_);
            $N->$_( $r->{$_} );
        }
        $N->synched;
        push @list, $N;
    }
    return @list;
}

=item empty

=cut

sub empty {
    my ($s) = @_;
    LOG("Clean ChannelUsers");
    my $db = App::IRC::Bot::Shoze::Db->new;
    $db->die_if_not_open();
    my $h     = $db->handle;
    my $query = <<SQL;
    DELETE FROM channel_userlist        
SQL
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute()
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    return $sth->rows;
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
