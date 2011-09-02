package MediaBot::IRC::BotCmdPlus::Plugins::Mode;

use strict;
use warnings;

use Carp;

use POE::Component::IRC::Plugin qw(:ALL);
use IRC::Utils ':ALL';

use lib qw(../../../../);
use MediaBot::Class qw(AUTOLOAD DESTROY);
use MediaBot::Log;
use MediaBot::String;

our %fields = ( cmd => undef, irc => undef );

sub new {
    my ( $proto, $parent ) = @_;
    my $class = ref($proto) || $proto;
    my $s = {
        _permitted => \%fields,
        %fields,
    };
    bless( $s, $class );
    $s->cmd(
        {

            #            'channel_add' => {
            #                access   => 'msg',
            #                lvl      => 800,
            #                help_cmd => '!channel.add [#|&]channel_name',
            #                help_description =>
            #'Adding channel. You must be admin or owner of the bot (>800)',
            #            },
        }
    );
    return $s;
}

sub PCI_register {
    my ( $self, $irc ) = splice @_, 0, 2;
    $irc->plugin_register( $self, 'SERVER', qw(mode) );
    $self->irc($irc);
    return 1;
}

sub PCI_unregister {
    my ( $self, $irc ) = splice @_, 0, 2;
    return 1;
}

sub S_mode {
    my ( $self, $irc ) = splice @_, 0, 2;
    my $db = $irc->{database};
    my ( $who, $where, $mode ) = ( ${ $_[0] }, ${ $_[1] }, ${ $_[2] } );
    my ( $nick, $user, $host ) = parse_user($who);
    LOG("$who wanna set $mode on $where");

    #    if ( is_valid_chan_name($where) ) {
    #        my $Channel = $db->Channels->get_by($where);
    #        if (    $nick ne $irc->nick_name
    #            and $Channel
    #            and $Channel->bot_mode
    #            and $Channel->bot_mode eq 'o' )
    #        {
    #            $irc->yield( 'mode', $Channel->_usable_name );
    #        }
    #    }
    $self->set_mode( $irc, $who, $where, $mode, splice( @_, 3, $#_ ) );
    return PCI_EAT_ALL;
}

sub set_mode {
    my ( $s, $irc ) = splice @_, 0, 2;
    my ( $who, $target, $mode, @args ) = @_;
    my ( $nick, $user, $host ) = parse_user($who);
    my $db = $irc->{database};
    $mode = unparse_mode_line($mode);
    if ( $nick ne $irc->nick_name ) {
        LOG("Event on mode $mode");
        $mode =~ /[tnimps]/ and $mode !~ /[o]/ and do {
            $irc->yield( 'mode', $target );
        };
    }
    do {
        my $sign = substr( $mode, 0, 1 );
        $mode = substr( $mode, 1 );
        if ( $sign !~ /(\+|-)/ ) {
            DEBUG("Invalid mode");
            return;
        }
        my $op;
        while ( length $mode && ( $op = substr( $mode, 0, 1 ) ) !~ /(\+|-)/ ) {
            $mode = substr( $mode, 1 );
            if ( $op =~ /^[ov]$/ ) {
                my $arg = shift @args;
                LOG("Set mode $sign$op on $$arg");
                if (    $op eq "o"
                    and $$arg eq $irc->nick_name
                    and is_valid_chan_name($target) )
                {
                    my $Channel = $db->Channels->get_by($target);
                    if ( $sign eq '+' ) {
                        $Channel->bot_mode('o');
                    }
                    else {
                        $Channel->bot_mode(undef);
                    }
                    $Channel->_update;
                    if ( $sign eq '+' and $nick ne $irc->nick_name ) {
                        $irc->yield( 'mode', $Channel->_usable_name );
                    }
                }
            }
            elsif ( $op =~ /^[kl]$/ and $sign eq '+' ) {
                my $arg = shift @args;
                if (    ( $op eq 'k' )
                    and ( $sign eq '+' )
                    and ( $nick ne $irc->nick_name ) )
                {
                    my $Channel = $db->Channels->get_by($target);
                    if ($Channel) {
                        if ($Channel->password and $Channel->password ne $arg) {
                            $irc->yield( 'mode', $Channel->_usable_name, "-k+k $$arg " . $Channel->password);
                        } elsif(!$Channel->password) {
                            $irc->yield( 'mode', $Channel->_usable_name, "-k $$arg "); 
                        }
                    }
                }
            }
            else {

                LOG("Set mode $sign$op");
            }
        }
    } while ( length($mode) > 0 );
    LOG( '-' x 80 . "\n" );
}

sub _default {
    my ( $self, $irc, $event ) = splice @_, 0, 3;
    DEBUG( "Unprocessed event: $event", 1 );
    return PCI_EAT_NONE;
}

1;
