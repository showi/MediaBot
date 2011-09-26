###############################################################################
# This module permit to launc external command into sub process (fork)
# On exit the subprocess emit an event that requesting plugin can listen
# This plugin is a rewrite of a recipe found on POE Cookbook
#
# Todo: Write SubTask::Request and SubTask::Response
###############################################################################
package App::IRC::Bot::Shoze::POE::SubTask;

use strict;
use warnings;

use Carp;

use YAML;
use POE qw(Wheel::Run Filter::Reference);
sub MAX_CONCURRENT_TASKS () { 3 }

use Storable;

use lib qw(../../../../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Constants;
use App::IRC::Bot::Shoze::Log;
use App::IRC::Bot::Shoze::POE::SubTask::Result;

use Data::Dumper qw(Dumper);

our %fields = (
    _parent => undef,
    alias   => undef,
    session => undef,
    tasks   => undef,
);

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
    $s->alias("SubTask");
    $s->tasks( [] );
    return $s;
}

sub _stop {
    DEBUG( "Deleting session with alias " . $_[OBJECT]->alias, 1 );
    delete $_[OBJECT]->{session};
}

sub add_task {
    my ( $s, $data ) = @_;
    push @{ $s->tasks }, $data;
    LOG( __PACKAGE__ . '::add_task(' . $s . " ### " . $data->{name} . ')' );
    unless ( $s->session ) {
        $s->session(
            POE::Session->create(
                object_states => [
                    $s => [
                        qw(_start _stop next_task task_result task_done task_debug sig_child)
                    ],
                ]
            )
        );
    }
    $poe_kernel->post( $s->session, 'next_task' );
}

# Start the session that will manage all the children.  The _start and
# next_task events are handled by the same function.

# Start as many tasks as needed so that the number of tasks is no more
# than MAX_CONCURRENT_TASKS.  Every wheel event is accompanied by the
# wheel's ID.  This function saves each wheel by its ID so it can be
# referred to when its events are handled.
# Wheel::Run's Program may be a code reference.  Here it's called via
# a short anonymous sub so we can pass in parameters.
sub _start {
    shift->start_tasks(@_);
}

sub next_task {
    my $s = shift;
    print "SELF: $s\n";
    $s->start_tasks(@_);
}

sub start_tasks {
    my $s = $_[OBJECT];
    my ( $kernel, $heap ) = @_[ KERNEL, HEAP ];
    LOG("Start task");
    while ( keys( %{ $heap->{task} } ) < MAX_CONCURRENT_TASKS ) {
        my $next_task = shift @{ $s->tasks };
        last unless defined $next_task;
        LOG("Starting task for $next_task->{name} ...");
        my $task = POE::Wheel::Run->new(
            Program => sub { do_stuff($next_task) },
            StdoutFilter => POE::Filter::Reference->new(),
            StdoutEvent  => "task_result",
            StderrEvent  => "task_debug",
            CloseEvent   => "task_done",
        );
        $heap->{task}->{ $task->ID } = $task;
        $kernel->sig_child( $task->PID, "sig_child" );
    }
}

# This function is not a POE function!  It is a plain sub that will be
# run in a forked off child.  It uses POE::Filter::Reference so that
# it can return arbitrary information.  All POE filters can be used by
# themselves, but their parameters and return values are always list
# references.
sub do_stuff {
    my $s = $_[OBJECT];
    binmode(STDOUT);    # Required for this to work on MSWin32
    my $task   = shift;
    my $filter = POE::Filter::Reference->new();

    my $cmd       = $task->program . " " . $task->args;
    my $cmdresult = `$cmd`;
    my $cmdstatus = $? . "";
    my $r         = {};
    $r = new App::IRC::Bot::Shoze::POE::SubTask::Result;
    for my $k ( keys %{$task->{_permitted}} ) {
        next unless defined $task->$k;
        $r->$k($task->$k);
    }
    $r->data($cmdresult) if $cmdresult;
    $r->status($cmdstatus) if defined $cmdstatus;

    # Generate some output via the filter.  Note the strange use of list
    # references.

    #to a true value. To enable deserialization, $Storable::Eval
    my $output = $filter->put( [$r] );
    print @$output;
}

# Handle information returned from the task.  Since we're using
# POE::Filter::Reference, the $result is however it was created in the
# child process.  In this sample, it's a hash reference.
sub task_result {
    my $s = $_[OBJECT];
    my $r = $_[ARG0];

#    print "SessionID: " . $r->session_id . ", Event: " .  $r->event . "\n";
#    $_[KERNEL]->post($r->session_id, $r->event , $r->who => $r->where => $r );
#    $_[KERNEL]->post($r->session_id, 'privmsg', "#erreur404", "Coucou");
#    my $session = $_[KERNEL]->ID_id_to_session($r->session_id);#->{heap}->send_even($r->event, $r->who => $r->where => $r);
#     $_[KERNEL]->post($session->[HEAP]{irc}, $r->event , $r->who => $r->where => $r );
    my $irc = $s->_parent->IRC->components->{$r->session_id};
    $irc->send_event($r->event , $r->who => $r->where => $r);
    #$session->{HEAP}->
}

# Catch and display information from the child's STDERR.  This was
# useful for debugging since the child's warnings and errors were not
# being displayed otherwise.
sub task_debug {
    my $s      = $_[OBJECT];
    my $result = $_[ARG0];
    print "Debug: $result\n";
}

# The task is done.  Delete the child wheel, and try to start a new
# task to take its place.
sub task_done {
    my $s = $_[OBJECT];
    my ( $kernel, $heap, $task_id ) = @_[ KERNEL, HEAP, ARG0 ];
    delete $heap->{task}->{$task_id};
    $kernel->yield("next_task");
}

# Detect the CHLD signal as each of our children exits.
sub sig_child {
    my $s = $_[OBJECT];
    my ( $heap, $sig, $pid, $exit_val ) = @_[ HEAP, ARG0, ARG1, ARG2 ];
    my $details = delete $heap->{$pid};

    LOG("warn $$: Child $pid exited");
}

1;
