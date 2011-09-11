package App::IRC::Bot::Shoze::POE::IRC::Out;

use strict;
use warnings;

use Carp;

use POE;

#use POE::Component::IRC::Plugin qw(:ALL);

use IRC::Utils ':ALL';

use lib qw(../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD _get_root DESTROY);
use App::IRC::Bot::Shoze::Constants qw(:ALL);
use App::IRC::Bot::Shoze::Log;

use Data::Dumper qw(Dumper);

our %fields = ( _parent => undef );

sub new {
    my ( $proto, $parent ) = @_;
    croak "No parent object passed as first parameter"
      unless ref($parent);
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    $s->_parent($parent);
    return $s;
}

sub join {
    my ( $s, $User, $channame ) = @_;
    $channame =~ /^([#&])([\w\d_-]+)$/ or do {
        WARN("Invalid channel name '$channame'");
        return BOT_CHAN_INVALIDNAME; 
    };
    my ( $type, $name ) = ( $1, $2 );
    my $db = $s->_get_root->Db;
    my $Channel = $db->Channels->get_by( { type => $type, name => $name } );
    unless ($Channel) {
        WARN("Cannot join unregistered channel $type$name.");
        return BOT_CHAN_UNREGISTERED;
    }
    if ( $Channel->bot_joined ) {
        WARN("Bot already joined '$type$name'.");
        return BOT_CHAN_ALEARDYJOINED;
    }
    unless ( $Channel->active ) {
        WARN("Channel $channame is not active, cannot join $channame.");
        return BOT_CHAN_NOTACTIVE;
    }
    if ($User->lvl < 800 and $User->id != $Channel->owner) {
        WARN("User access too low, cannot joinr channel $channame");
        return BOT_USER_ACCESSDENIED; 
    }
    my $msg = $channame;
    $msg .= " " .$Channel->password if $Channel->password;
    $s->_parent->poco->yield(join => $msg);
    return BOT_OK;
}

sub part {
    my ( $s, $User, $channame ) = @_;
    $channame =~ /^([#&])([\w\d_-]+)$/ or do {
        WARN("Invalid channel name '$channame'");
        return BOT_CHAN_INVALIDNAME; 
    };
    my ( $type, $name ) = ( $1, $2 );
    my $db = $s->_get_root->Db;
    my $Channel = $db->Channels->get_by( {type => $type, name => $name} );
    unless ($Channel) {
        WARN("Cannot part unregistered channel $type$name.");
        return BOT_CHAN_UNREGISTERED;
    }
    if ( !$Channel->bot_joined ) {
        WARN("Bot is not on  '$type$name'.");
        return BOT_CHAN_NOTJOINED;
    }
    if ($User->lvl < 800 and $User->id != $Channel->owner) {
        WARN("User access too low, cannot joinr channel $channame");
        return BOT_USER_ACCESSDENIED; 
    }
  
    $s->_parent->poco->yield(part => $channame);
    return BOT_OK;
}

1;
