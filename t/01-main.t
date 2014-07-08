#!/usr/bin/env perl
use strict;
use Test::More tests => 2;
use Socket;
use POSIX;
use Data::Dumper;

my $WORKERS_COUNT = 5;
my $PORT = 55555;

my $RESULTS = {};
# 1 Import

use_ok('AnyEvent::TCP::Server');

require AnyEvent::TCP::Server;
import AnyEvent::TCP::Server;


my $ae_tcp_server = AnyEvent::TCP::Server->new(
    process_request =>  sub {
        my ($worker, $fh) = @_;

        syswrite $fh, "$$";
        $fh->close();
    },
    workers         =>  $WORKERS_COUNT,
    port            =>  $PORT,
);

my $pid = fork;

unless ($pid) {
    $ae_tcp_server->run();
}
else {
    sleep 2;

    test_tcp_server();
    kill POSIX::SIGTERM, $pid; 
    # exit 1;
}

sub test_tcp_server {
    # test stage
    for (1 .. $WORKERS_COUNT) {
        my $data = do_request();
        $RESULTS->{$data} = 1;
    }
    #verify stage
    if (scalar keys %$RESULTS != $WORKERS_COUNT) {
        BAIL_OUT('Something wrong');
    }
    for (1 .. $WORKERS_COUNT) {
        my $data = do_request();
        if (!$RESULTS->{$data}) {
            BAIL_OUT("Missing data");
        }
    }
    ok 1, 'TCP connection test';
}

sub do_request {
    socket(SOCKET,PF_INET,SOCK_STREAM,(getprotobyname('tcp'))[2])
        or die "Can't create a socket $!\n";
    connect( SOCKET, pack_sockaddr_in($PORT, inet_aton('localhost')))
        or die "Can't connect to port $PORT! \n";
    my $data; sysread SOCKET, $data, 16;
    close SOCKET;
    return $data
}

1;
