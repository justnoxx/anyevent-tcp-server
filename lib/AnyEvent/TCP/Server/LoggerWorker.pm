package AnyEvent::TCP::Server::LoggerWorker;

use strict;
use IO::Socket::INET;
use AnyEvent::TCP::Server::AbstractWorker;
use base qw/AnyEvent::TCP::Server::AbstractWorker/;

use AnyEvent::TCP::Server::Log qw/init_logger/;

sub spawn {
    my ($self, %params) = @_;

    return $self->SUPER::spawn(
        type        => 'process_worker',
        number      =>  $params{number},
        procname    =>  $params{procname},
        worker_does => sub {
            my ($self) = @_;
            $self->{logger} = init_logger();
            open my $fh, '>', '/tmp/lw.log' or die "Something bad $!";
            $self->{fh} = $fh;
        },
        run         => sub {
            my ($self) = @_;

            my $log_chunk =  $self->{logger}->recv();

            if ( $log_chunk ) {
                print STDOUT $log_chunk;
            }
        },
        master_does => sub {
            1;
        },
    );
}


1;
