#!/usr/bin/env perl
use strict;
use warnings;
use Data::Dumper;
use AnyEvent::Handle;
use AnyEvent;

use FindBin qw($Bin);
use lib qq{$Bin/../lib};

use AnyEvent::TCP::Server;
use AnyEvent::TCP::Server::Log qw/log_client/;

my $ae = AnyEvent::TCP::Server->new(
    port                =>  44444,
    # если этот хендлер есть, то эта функция будет вызвана по конекту
    # так получилось, что я не имею доступа к данным клиента из воркера.
    # проброс данных клиента замедляет сервер в 3-4 раза.
    # эта функция должна возвращать 1 или 0, если 1, то воркер получит это задание, если нет,
    # то конект будет оборван.
    
    check_on_connect    =>  sub {
        my ($fh, $host, $port) = @_;
        # warn "on connect: $$";
        # if (time() =~ m/[789]$/s) {
        #     syswrite $fh, "GO AWAY!\n";
        #     return 0;
        # }
        return 1;
    },

    # подключение лога:
    log                 =>  {
        filename        =>  '/Users/noxx/git/anyevent-tcp-server/eg/my_http.log',
        append          =>  1,
        # format_string   =>  '[%year-%mon-%mday %hour:%min:%sec] %msg %n',
    },
    process_request     =>  sub {
        # warn 'Processing Request...';
        my ($worker_object, $fh, $client) = @_;
        my $log = log_client();
        # my $log = $worker_object->{logger};
        $log->log("Request!");
        # warn Dumper $log;
        binmode $fh, ':raw';
        my $rw;$rw = AE::io $fh, 0, sub {
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
    };
        
    },
    # sock_path             =>  '/Users/noxx/git/anyevent-tcp-server/eg',
    workers               =>  5,
    debug               =>  1,
    # procname            =>  'test.pl'
    # pid                 =>  '/home/noxx/git/anyevent-tcp-server/eg/ae.pid',
    # daemonize           =>  1,
);

$ae->run();
