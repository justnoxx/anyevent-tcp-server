#!/usr/bin/env perl
use strict;
use warnings;
use Data::Dumper;
use AnyEvent::Handle;
use AnyEvent;

use AnyEvent::TCP::Server;

my $ae = AnyEvent::TCP::Server->new(
    port                =>  44444,
    process_request     =>  sub {
        my ($worker_object, $fh, $client) = @_;

        binmode $fh, ':raw';

        my $rw;$rw = AE::io $fh, 0, sub {
        if ( sysread ( $fh, my $buf, 1024*40 ) > 0 ) {
            warn "ME: $$";
            syswrite( $fh, "HTTP/1.1 200 OK\015\012Connection:close\015\012Content-Type:text/plain\015\012Content-Length:4\015\012\015\012Good" );
            undef $rw;
        }
        elsif ($! == Errno::EAGAIN) {
            return;
        }
        else {
            undef $rw;
        }
    };
        
    },
    # sock_path             =>  '/Users/noxx/git/anyevent-tcp-server/eg',
    workers             =>  50,
    # debug               =>  1,
    # procname            =>  'test.pl'
    # pid                 =>  '/home/noxx/git/anyevent-tcp-server/eg/ae.pid',
    # daemonize           =>  1,
);

$ae->run();