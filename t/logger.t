#!/usr/bin/perl

use strict;
use warnings;
use POSIX ":sys_wait_h";

use AnyEvent::TCP::Server::Log qw(log_client init_logger log_conf);
#use Test::More;


log_conf(
    port => 10502,
    host => 'localhost',
);

my $server = init_logger();

for ( 1 .. 3 ) {
    my $pid = fork();
    if ( $pid ) {
        my $client = log_client();
        $client->log("Client $pid");
    }
}

my $kid = 1;
do {
    $kid = waitpid(-1, WNOHANG);
    my $log_str = $server->recv();
    print $log_str;
} while $kid > 0;




