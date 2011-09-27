package App::IRC::Bot::Shoze::HTTP::Channels;

=head1 NAME

App::IRC::Bot::Shoze::HTTP::Channels

=cut

=head1 SYNOPSIS

=cut

use strict;
use warnings;

use Carp;

use HTTP::Response;
use YAML qw'freeze thaw Bless';

use lib qw(../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Log;
our $AUTOLOAD;

our %fields = (
    _parent  => undef,
);

=head1 SUBROUTINES/METHODS

=over

=item new

=cut

sub new {
    my ( $proto, $parent ) = @_;
    DEBUG( "Creating new " . __PACKAGE__, 5 );
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

=item list

=cut

sub list {
    my ($s, $User, $response) = @_;
    my $db = $s->_get_root->Db;
    my @data;
    for($db->Channels->list) {
       # $content .= "<tr><td>".$_->_usable_name ."</td><td>".$_->owner."</td></tr>";
        my %h;
        for my $k (keys %{$_}) {
            next if $k =~ /^_/;
            $h{$k} = $_->{$k};
        }
        push @data, \%h;
    }
    my $ser = freeze(\@data);
    print "Ser: $ser\n";
    $response->content($ser);
    return $response;
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
