package App::IRC::Bot::Shoze::POE::SubTask;

use strict;
use warnings;

use Carp;

use YAML;
use POE qw(Wheel::Run Filter::Reference);
sub MAX_CONCURRENT_TASKS () { 3 }

use Storable;

use lib qw(../../);
use App::IRC::Bot::Shoze::Class qw(AUTOLOAD DESTROY _get_root);
use App::IRC::Bot::Shoze::Constants;
use App::IRC::Bot::Shoze::Log;

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
    $s->tasks( []);#'[qw(one two three four five six seven eight nine ten)] );

    $s->session(
        POE::Session->create(
            object_states => [
                $s => [
                    qw(_start _stop next_task task_result task_done task_debug sig_child)
                ],
              ]
        )
    );
#    $s->add_task( { name => "tld", program => "/home/sho/workspace/MediaBot/App-IRC-Bot-Shoze/scripts/tld.pl", args => 'co', callback => 'tld_response'} );
#    $s->add_task( { name => "tld", program => "/home/sho/workspace/MediaBot/App-IRC-Bot-Shoze/scripts/tld.pl", args => 'jp' } );
#    $s->add_task( { name => "tld", program => "/home/sho/workspace/MediaBot/App-IRC-Bot-Shoze/scripts/tld.pl", args => 'com' } );
#    $s->add_task( { name => "tld", program => "/home/sho/workspace/MediaBot/App-IRC-Bot-Shoze/scripts/tld.pl", args => '한국' , action => 'privmsg', where => 'erreur404'} );
#    $s->add_task( { name => "tld", program => "../scripts/tld.pl", args => 'jp' } );
#    $s->add_task( { name => "tld", program => "../scripts/tld.pl", args => 'io' } );
#    $s->add_task(
#        { name => "tld", program => "../scripts/tld.pl", args => '한국' } )
#      ;
        $s->add_task(
       
            {
                name => "tld",
                program =>
"/home/sho/workspace/MediaBot/App-IRC-Bot-Shoze/scripts/tld.pl",
                args  => 'jp',
                event => 'irc_tld_result',
                who   => "sho",
                where => '#erreur404',
            }
        
    );
    return $s;
}


sub _stop {
    DEBUG( "Deleting session with alias " . $_[OBJECT]->alias, 1 );
    delete $_[OBJECT]->{session};
}

sub add_task {
    my ( $s, $data ) = @_;
    push @{ $s->tasks }, $data;
    LOG(__PACKAGE__ . '::add_task(' . $s . " ### " .$data->{name} . ')');
    LOG("###########");
    #print Dumper $s;
    LOG("###########");
    unless($s->session) {
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
    
    #$s->session->kernel->yield("next_task");
    #$s->start_tasks;
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
        LOG("#####");
        #LOG(YAML::Dump($next_task));
        LOG("#####");
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

    # Simulate a long, blocking task.
    sleep( rand 5 );

    #    if (ref($task)) {
    #        print "Executing sub task: " . $task->{name} . "\n";
    #    }
    #    # Generate a bogus result.  Note that this result will be passed by
    # reference back to the parent process via POE::Filter::Reference.
    #print STDERR "Event: " . $task->{event} . "\n";
    my $cmd = $task->{program} . " " . $task->{args};
    my $cmdresult = `$cmd`;
    my $cmdstatus = $? . "";
#    my $result = {
#        name   => $task->{name} . "",
#        result => $cmdresult,
#        status => $cmdstatus,
#        who => $task->{who} . "",
#        where => $task->{where} . "",
#        event => $task->{event} . "" || 'irc_tld_ressult',
#    };
    my $r = {};
    for my $k (keys %{$task}) {
        next unless defined $task->{$k};
        $r->{$k} = $task->{$k};
    }
    $r->{result} = $cmdresult if $cmdresult;
    $r->{status} = $cmdstatus if defined $cmdstatus;
    #$r->{name} = $task->{name} if $task->{name};    
    #$result{callback} = $task->{callback} if $task->{callback};

    # Generate some output via the filter.  Note the strange use of list
    # references.

    #to a true value. To enable deserialization, $Storable::Eval
    my $output = $filter->put( [ $r ] );
    print @$output;
}

# Handle information returned from the task.  Since we're using
# POE::Filter::Reference, the $result is however it was created in the
# child process.  In this sample, it's a hash reference.
sub task_result {
    my $s      = $_[OBJECT];
    my $r = $_[ARG0];
    LOG("Task result");
    LOG(YAML::Dump($_[ARG0]));
   #print "[$s] Result for $result->{task}: $result->{result} ( $result->{status} )\n";
#    my $cmd = $s->_get_root->POE->IRC->poco->plugin_get('BotCmdPlus')->get_cmd('tld')->{plugin};
#    print "CMD: $cmd\n";
#    $cmd->_callback();# if ref($cmd);
#print Dumper $r;

    $s->_get_root->POE->IRC->poco->send_event(
        $r->{event} => $r->{who} => $r->{where} => $r->{result}
    );

#    if (defined $result->{callback}) {
#        print "Executing Callback\n";
#        my $callback = $result->{callback};
#        $s->$callback($result);
#    }
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

# Run until there are no more tasks.
#$poe_kernel->run();
#exit 0;
