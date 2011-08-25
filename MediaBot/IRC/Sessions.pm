package MediaBot::IRC::Sessions;
use strict;
use warnings;

use Carp;
use Exporter;
use POE::Session;

use lib qw(../../);
use MediaBot::Class qw(AUTOLOAD DESTROY _get_root);
use MediaBot::Log;
use Data::Dumper;

our @ISA    = qw(Exporter);
our @EXPORT = qw();

our $AUTOLOAD;

our %fields = ( _parent => undef, );

# Constructor
#############
sub new {
    my ( $proto, $parent ) = @_;
    DEBUG("Creating new " . __PACKAGE__);
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


sub add {
    my ( $s, $nick, $ident, $host ) = @_;
    print "Session add: $nick $ident@" . "$host\n";
    my $dbs = $s->_get_root->Db->Sessions;
    $dbs->delete_idle();
    my $err = $dbs->create( $nick, $ident, $host );
    my $S;
    unless( !$err or $err == 1 ) {
        return 0;
    };
    $S = $dbs->get( $nick, $ident, $host );
    $dbs->update_newrequest($S);
    return $S;
}

1;
