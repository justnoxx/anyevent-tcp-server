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
            my $self->{logger} = init_logger();

        },
        run         => sub {
            my ($wo) = @_;
            my $log_chunk;
            my $self->{logger}->recv($log_chunk,4096);

            if ( $log_chunk ) {
                print STDOUT $log_chunk;
            }
        }
    );
}


1;
