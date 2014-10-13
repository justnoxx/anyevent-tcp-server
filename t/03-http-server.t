#!/usr/bin/env perl
# This test was created for full and complex
# AETCPSRVR package testing.
use strict;
use warnings;
use AETCPSRVR;
use Cwd qw/getcwd/;
use System::Process;
use Test::More;
use POSIX;
use AnyEvent;
use AnyEvent::HTTP;


my $cwd = getcwd();

our $PIDFILE = $cwd . '/.aetcpsrvr.pid';
our $LOGFILE = $cwd . '/.aetcpsrvr.log';
our $PROCNAME = 'AETCPSRVRTEST';

my %params = get_init_parameters();

start_server(%params);

start_tests();


sub start_server {
    my %init = @_;
    if (-e $LOGFILE) {
        unlink ($LOGFILE);
    }
    my $pid = fork();
    unless ($pid) {
        no Test::More;
        my $server = AETCPSRVR->new(%init);
        $server->run();
    }
    else {
        sleep 3;
    }
}


sub start_tests {
    sleep 3;
    my $pid = System::Process::pidinfo(file => $PIDFILE);

    unless ($pid) {
        BAIL_OUT "Master process is offline.";
    }


    ### 1 test ###
    # server online
    ok($pid, "Server is online");


    ### 2 test ###
    # at first, we'll check, is process name in pid master.
    my $command = $pid->command();
    ok($command =~ m/$PROCNAME\smaster/, 'Master process has correct name');


    ### 3 test ###
    # let's check http_response
    my $cv = AnyEvent->condvar();
    my $guard; $guard = http_get "http://localhost:44444", sub {
        undef $guard;
        my ($content, undef) = @_;
        is ($content, 'Good', "HTTP server answered with right answer");
        $cv->send("HTTP_REQUEST_DONE");
    };
    my $state = $cv->recv();
    undef $cv;

    ### 4 test ###
    # let's check logfile's content
    open LOGFILE, $LOGFILE;
    my @content = <LOGFILE>;
    my $ok = 0;
    for (@content) {
        $ok++ if m/ON_CONNECT_HANDLER\s$/s;
        $ok++ if m/REQUEST\s$/s;
    }
    is($ok, 2, "Logfile content ok");
    

    ### 5 test ###
    # let's kill one of workers for respawn check
    use Data::Dumper;
    my $pids = System::Process::pidinfo pattern => "$PROCNAME\\s+process_worker";

    ok(scalar @$pids, "Worker processes are alive");


    ### 6 test ###
    # let's check worker processes count
    is(scalar @$pids, 2, "Worker processes count ok");


    ### 7 test ###
    # calculate pid checksum and kill one process.
    my $checksum1 = 0;
    for my $p (@$pids) {
        $checksum1 += $p->pid();
    }

    $pids->[0]->kill(POSIX::SIGTERM);
    
    sleep 3;
    $pids = System::Process::pidinfo pattern => "$PROCNAME\\s+process_worker";
    # recover process check
    my $checksum2 = 0;
    is (scalar @$pids, 2, "Woker count after kill still ok");
    for my $p (@$pids) {
        $checksum2 += $p->pid();
    }
    

    ### 8 test ###
    # check diff between checksum
    ok ($checksum2 != $checksum1, "Process respawned ok");
    
    ### 9 && 10 test ###
    # check, are workers spawned correct
    my $log_size = -s $LOGFILE;
    
    $cv = AnyEvent->condvar();
    for my $pid(@$pids) {
        $cv->begin();
        my $guard; $guard = http_get "http://localhost:44444", sub {
            undef $guard;
            my ($content, $headers) = @_;
            
            is($content, 'Good', "Request ok");
            $cv->end();
        };
    }
    $cv->recv();
    
    ### 11 test ###
    # check logsize
    ok($log_size < -s $LOGFILE, "Logsize increased");

    
    ### 12 test ###
    # check logger worker correct respawn
    my $logger_worker = System::Process::pidinfo 
        pattern => "$PROCNAME\\slogger_worker";
    ok(scalar @$logger_worker, "Logger worker ok");
    

    ### 13 test ###
    # try to kill logger worker
    my $old_loggers_pid = $logger_worker->[0]->pid();
    $logger_worker->[0]->kill(POSIX::SIGTERM);
    $logger_worker = System::Process::pidinfo 
        pattern => "$PROCNAME\\slogger_worker";
    
    ok(scalar @$logger_worker, "Logger respawned");


    ### 14 ###
    # let's check logger's new PID
    ok ($old_loggers_pid ne $logger_worker->[0]->pid(), "Logger worker was respawned with new PID");
    
    
    ### 15 ###
    # we'll check, is worker able to write logs after respawn
    $log_size = -s $LOGFILE;
    undef $cv;
    $cv = AnyEvent->condvar();
    for (@$pids) {
        $cv->begin();
        my $guard; $guard = http_get "http://localhost:44444/", sub {
            undef $guard;
            my ($content, undef) = @_;
            is($content, 'Good', "Response still ok");
            $cv->end();
        };
    }
    $cv->recv();

    ok($log_size < -s $LOGFILE, "Logfile appended after respawn ok");

    ### 16 ###
    # this case was found by chance. When you'll kill process worker, then you'll kill logger worker, and then, finally,
    # server will crash. That is a critical bug, reason of which is not ehough cleanup at master startup.
    
    my $process_workers = System::Process::pidinfo pattern => "$PROCNAME\\s+process_worker";
    # kill 1st process worker
    ok($process_workers->[0]->kill(POSIX::SIGTERM), "Killing process_worker again");
    # kill logger worker
    ok($logger_worker->[0]->kill(POSIX::SIGTERM), "Killing logger");
    # kill another process worker
    ok($process_workers->[1]->kill(POSIX::SIGTERM), "Killing another process_worker");
    
    sleep 5;
    undef $cv;
    $cv = AnyEvent->condvar();
    #$guard = undef; $guard = http_get "http://localhost:44444/", sub {
    $guard = http_get "http://localhost:44444/", sub {
        undef $guard;
        my ($content, undef) = @_;
        is($content, 'Good', "Not affected by fork bug");
        $cv->send("DONE");
    };
    $cv->recv();

    done_testing();
    unlink $LOGFILE;
    unlink $PIDFILE;
    $pid->kill(POSIX::SIGTERM);
}

sub get_init_parameters {
    my %init_parameters = (
        port    =>  44444,
        check_on_connect => sub {
            my ($fh, $host, $port) = @_;
            my $log = AnyEvent::TCP::Server->get_logger();
            $log->log("ON_CONNECT_HANDLER");
            return 1;
        },
        log     =>  {
            filename    =>  $LOGFILE,
            append      =>  1,
            port        =>  44445,
        },
        process_request     =>  sub {
            my ($wo, $fh, undef) = @_;
            
            my $log = AETCPSRVR->get_logger();
            $log->log("REQUEST");
            binmode $fh, ':raw';
            my $rw; $rw = AE::io $fh, 0, sub {
                if ( sysread ( $fh, my $buf, 1024*40 ) > 0 ) { 
                    syswrite( $fh, "HTTP/1.1 200 OK\015\012Connection:close\015\012Content-Type:text/plain\015\012Content-Length:4\015\012\015\012Good" );
                    undef $rw;
                }
                elsif ($! == Errno::EAGAIN) {
                    return;
                }
                else {
                    undef $rw;
                }
            }
        },
        workers     =>  2,
        pid         =>  $PIDFILE,
        daemonize   =>  1,
        procname    =>  $PROCNAME,
 #       debug       =>  1,
    );
    return %init_parameters;
}


__END__


