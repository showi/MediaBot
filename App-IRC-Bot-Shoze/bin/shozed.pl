#!/usr/bin/perl 

use warnings;
use strict;

use Proc::Daemon;

my $BASE_PATH = "/srv/shoze/";
my $name      = "Shoze";

die "Need argument start|stop|restart|status"
  unless $ARGV[0] =~ /^(start|stop|restart|status)$/;

my $Shoze = Proc::Daemon->new(
    work_dir     => $BASE_PATH,
    child_STDOUT => "$BASE_PATH/log/shoze.log",
    child_STDERR => "$BASE_PATH/log/shoze.debug.log",
    pid_file     => "$BASE_PATH/run/shoze.pid",
    exec_command => 'perl -MCarp=verbose /usr/bin/shoze',
);

if ( $ARGV[0] eq "start" ) {
    my $pid = $Shoze->Init();
    die "Cannot start $name as a daemon" unless ($pid);
    print "$name started as daemon ($pid)\n";
}
elsif ( $ARGV[0] eq "stop" ) {
    if ( $Shoze->Status("$BASE_PATH/run/shoze.pid") ) {
        my $stopped = $Shoze->Kill_Daemon("$BASE_PATH/run/shoze.pid");
        if ($stopped) {
            print "$name stopped\n";
        }
        else {
            print "Cannot stop $name\n";
        }
    }
    else {
        print "$name is not started\n";
    }
}
elsif ( $ARGV[0] eq "restart" ) {
    if ( $Shoze->Status("$BASE_PATH/run/shoze.pid") ) {
        my $stopped = $Shoze->Kill_Daemon("$BASE_PATH/run/shoze.pid");
    }
    my $pid = $Shoze->Init();
}
elsif ( $ARGV[0] eq "status" ) {
    my $pid = $Shoze->Status();
    if ($pid) {
        print "$name is running pid:$pid\n";
    }
    else {
        print "$name is stopped\n";
    }
}

1;
