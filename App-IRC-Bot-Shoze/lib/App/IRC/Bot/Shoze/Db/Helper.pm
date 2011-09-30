package App::IRC::Bot::Shoze::Db::Helper;

=head1 NAME

App::IRC::Bot::Shoze::Db::Helper - Export methos used to load/unload database plugin

=cut

=head1 SYNOPSIS

=cut

use strict;
use warnings;

use Carp;


=head1 EXPORT_OK

=over

=item load

=item unload

=back

=cut

use Exporter;

our @TAGS =
  qw(load unload);
our @ISA         = qw(Exporter);
our @EXPORT_OK   = @TAGS;
our %EXPORT_TAGS = ( ALL => [@TAGS] );

use Class::Unload;
use Class::Inspector;

use lib qw(../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY);
use App::IRC::Bot::Shoze::Log;

=head1 SUBROUTINES/METHODS

=over

=item load

=cut

sub load {
    my ( $s, $type, $name ) = @_;
    if ( defined $s->{$name} ) {
        WARN("Plugin $name already loaded");
        return 0;
    }
    my $plugin =
      'App::IRC::Bot::Shoze::Plugins::' . $type . '::' . $name . '::Db';
    my $ret = eval "require $plugin";
    unless ($ret) {
        WARN("Cannot load plugin '$plugin'");
        return 0;
    }
    $plugin->import;
    $s->{_permitted}->{$name} = 1;
    $s->$name( $plugin->new($s) );
    LOG("Database plugin loaded: $plugin");
    return 1;
}

=item unload

=cut

sub unload {
    my ( $s, $type, $name ) = @_;
    unless ( defined $s->{$name} ) {
        WARN("Plugin $name is not loaded");
        return 0;
    }
    my $plugin =
        'App::IRC::Bot::Shoze::Plugins::' 
      . $type . '::' 
      . $name
      . '::Db';
      Class::Unload->unload($plugin);
      delete $s->{_permitted}->{$name};
      delete $s->{$name};
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