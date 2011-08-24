package MediaBot::IRC::Sessions;
use strict;
use warnings;

use Carp;
use Exporter;
use POE::Session;

use lib qw(../../);
use MediaBot::Class qw(AUTOLOAD DESTROY LOG _get_root);
use Data::Dumper;

our @ISA    = qw(Exporter);
our @EXPORT = qw();

our $AUTOLOAD;

our %fields = ( _parent => undef, );

# Constructor
#############
sub new {
    my ( $proto, $parent ) = @_;
    print "Creating new " . __PACKAGE__ . "\n";
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

sub update_last_request {
    my ($s, $U) = @_;    
    my $dbs = $s->_get_root->Db->Sessions;
    $dbs->update_last_request($U->id); 
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
