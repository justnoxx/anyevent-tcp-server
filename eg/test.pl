#!/usr/bin/env perl
use strict;
use warnings;

use AnyEvent::TCP::Server;

my $ae = AnyEvent::TCP::Server->new(
	port 				=>	44444,
	process_request 	=>	sub {1;},
	# sock_path 			=>	'/Users/noxx/git/anyevent-tcp-server/eg',
	workers 			=>	5,
);

$ae->run();