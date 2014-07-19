package AnyEvent::TCP::Server::ProcessWorker;
use strict;
use warnings;
use base qw/AnyEvent::TCP::Server::AbstractWorker/;

use Data::Dumper;
use Carp;
use AnyEvent;
use AnyEvent::Util qw/portable_socketpair fh_nonblocking/;
use IO::Socket::UNIX;
use IO::FDPass;

use AnyEvent::TCP::Server::Utils;

sub spawn {
    my ($self_p, %params) = @_;

    if (!$params{process_request} || ref $params{process_request} ne 'CODE') {
        croak 'Missing process_request handler';
    }

    no warnings qw/redefine/;
    *{AnyEvent::TCP::Server::ProcessWorker::process_request} = $params{process_request};

    return $self_p->SUPER::spawn(
        type        =>  'process_worker',
        number      =>  $params{number},
        procname    =>  $params{procname},
        prepare_to_spawn => sub {
            my ($self, $spawn_params) = @_;

            ($self->{reader}, $self->{writer}) = portable_socketpair();
            fh_nonblocking($self->{reader}, 1);
            fh_nonblocking($self->{writer}, 1);
            $self->condvar(AnyEvent->condvar());
        },
        master_does =>  sub {
            my ($self) = @_;
            $self->{reader}->close();
            return $self;
        },
        worker_does =>  sub {
            my ($self) = @_;
            $self->{writer}->close();
        },
        run         =>  sub {
            my ($wo) = @_;

            my $sw;
            $sw = AnyEvent->io(
                fh      =>  $wo->{reader},
                poll    =>  'r',
                cb      =>  sub {

                    # receive file descriptor from master
                    my $fd = IO::FDPass::recv fileno $wo->{reader};

                    open my $fh, "+<&=$fd" or do {
                        dbg_msg "Unable to convert file descriptor to handle: $!";
                        # self-kill, if file descriptor is broken. Master will handle it.
                        # If master dead, there are no one, who cares.
                        # $self->sepukku();
                    };
                    
                    # process request with user subroutine
                    $wo->process_request($fh, {});
                },
            );
            $wo->condvar()->recv();
        },
    );
}


sub process_request {
    1;
}

1;

__END__