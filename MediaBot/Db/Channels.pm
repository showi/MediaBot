package MediaBot::Db::Channels;

use strict;
use warnings;

use Carp;

use IRC::Utils qw(:ALL);

use lib qw(../../);
use MediaBot::Class qw(AUTOLOAD DESTROY _get_root);
use MediaBot::Db::Channels::Object qw();
use MediaBot::Log;

our $AUTOLOAD;

our %fields = (
    _handle => undef,
    _parent => undef,
);

# Constructor
#############
sub new {
    my ( $proto, $parent ) = @_;
    DEBUG( "Creating new " . __PACKAGE__ );
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

sub list {
    my $s = shift;
    my $C = new MediaBot::Db::Channels::Object( $s->_parent );
    return $C->_list();
}

sub get_by {
    my ( $s, $type, $name ) = @_;
    unless ($name) {
        $type =~ /^(#|&)(.*)$/
          or croak "Invalid channel name";
        ( $type, $name ) = ( $1, $2 );
    }
    croak "Invalid channel name $type$name"
      unless is_valid_chan_name("$type$name");
    LOG( __PACKAGE__ . "::get_by($type, $name)" );
    my $C = new MediaBot::Db::Channels::Object( $s->_parent );
    return $C->_get_by( { name => $name, type => $type } );
}

sub create {
    my ( $s, $type, $name, $owner ) = @_;
    my $C = new MediaBot::Db::Channels::Object( $s->_parent );
    $C->type($type);
    $C->name($name);
    $C->owner($owner);
    return $C->_create();
}

sub clear_joined {
    my ($s) = @_;
    $s->_parent->die_if_not_open();
    my $h     = $s->_parent->handle;
    my $query = <<SQL;
		UPDATE channels SET bot_joined = NULL;
SQL
    my $sth = $h->prepare($query)
      or die "Cannot prepare query '$query' (" . $h->errstr . ")";
    $sth->execute()
      or die "Cannot execute query '$query' (" . $h->errstr . ")";
    return $sth->rows;
}
