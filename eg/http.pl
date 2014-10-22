#!/usr/bin/env perl
use strict;
use warnings;
use Data::Dumper;
use AnyEvent::Handle;
use AnyEvent;
use Socket;

use FindBin qw($Bin);
use lib qq{$Bin/../lib};

use AnyEvent::TCP::Server;

my $ae = AnyEvent::TCP::Server->new(
    port                =>  44444,
    check_on_connect    =>  sub {
        my ($fh, $host, $port) = @_;
        # warn "on connect: $$";
        # if (time() =~ m/[789]$/s) {
        #     syswrite $fh, "GO AWAY!\n";
        #     return 0;
        # }
        return 1;
    },

    # enabling log
    log                 =>  {
        filename        =>  '/home/noxx/git/anyevent-tcp-server/eg/ae.log',
        append          =>  1,
        port            =>  55557,
    },
    process_request     =>  sub {
        my ($worker_object, $fh, $client) = @_;
        my $log = AnyEvent::TCP::Server->get_logger();
        $log->log('Client: ', Dumper inet_ntoa($client->{host}));
        $log->log("Request!");
        #$log->splunk_log(
        #    msg     =>  'Request!',
        #    error   =>  0,
        #    data    =>  'AETCPSRVR'
        #);
        binmode $fh, ':raw';
        my $rw;$rw = AE::io $fh, 0, sub {
            if ( sysread ( $fh, my $buf, 1024*40 ) > 0 ) {
                print "MY BUF: ", $buf, "\n";               
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
    workers                 =>  9,
    debug                   =>  1,
    # procname                =>  'test.pl'
    # pid                     =>  '/home/noxx/git/anyevent-tcp-server/eg/ae.pid',
    daemonize               =>  1,
);

$ae->run();
