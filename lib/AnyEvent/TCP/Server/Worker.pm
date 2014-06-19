package AnyEvent::TCP::Server::Worker;

use strict;
use warnings;
# use diagnostics;

use Data::Dumper;
use Carp;
use AnyEvent;
use AnyEvent::Util qw/portable_socketpair fh_nonblocking/;
use IO::Socket::UNIX;
use IO::FDPass;

use AnyEvent::TCP::Server::Utils;
use AnyEvent::TCP::Server::Log;

sub spawn {
    my ($class, $params, $worker_number) = @_;

    unless ($worker_number) {
        croak "Can't spawn worker without number";
    }

    my $self = {
        process_request     =>  $params->{process_request},
        procname            =>  'AE::TCP::Server::Worker',
        client_forwarding   =>  $params->{client_forwarding},
    };

    if ($params->{_log}) {
        $self->{can_create_log_object} = 1;
        $self->{_log} = $params->{_log};
    }

    bless $self, $class;

    if ($params->{procname}) {
        $self->{procname} = $params->{procname} . ' worker';
    }

    $self->worker_no($worker_number);

    ($self->{reader}, $self->{writer}) = portable_socketpair();


    fh_nonblocking($self->{reader}, 1);
    fh_nonblocking($self->{writer}, 1);

    if ($self->{client_forwarding}) {
        ($self->{fwd_reader}, $self->{fwd_writer}) = portable_socketpair();
        fh_nonblocking($self->{fwd_reader}, 1);
        fh_nonblocking($self->{fwd_writer}, 1);
    }
    
    my $pid = fork();

    # master
    if ($pid) {
        # в мастере reader сокет не нужен, пока-что
        $self->{reader}->close();
        if ($self->{client_forwarding}) {
            $self->{fwd_reader}->close();
        }

        $self->{pid} = $pid;
        return $self;
    }
    # worker
    else {
        $self->{writer}->close();
        if ($self->{client_forwarding}) {
            $self->{fwd_writer}->close();
        }

        $self->{pid} = $$;
        $self->run();
    }
}


sub pid {
    my $self = shift;

    return $self->{pid};
}


# возможность для воркера выстрелить себе в ногу
sub sepukku {
    exit 1;
}


sub run {
    my ($self) = @_;

    procname $self->{procname};

    my $sw;

    $sw = AnyEvent->io(
        fh      =>  $self->{reader},
        poll    =>  'r',
        cb      =>  sub {

            my $fd = IO::FDPass::recv fileno $self->{reader};

            open my $fh, "+<&=$fd" or do {
                dbg_msg "Unable to convert file descriptor to handle: $!";
                # самоуничтожаемся, если дескриптор битый - лучше так, а мастер потом разберется
                # а если мастер сдох, то никто это не обработает и все опять в выигрыше
                $self->sepukku();
            };
            my $sub = $self->{process_request};
            $sub->($self, $fh, {});
            undef $sub;
        },
    );

    AnyEvent->condvar->recv();
}


sub rdr_socket {
    my $self = shift;
    return $self->{reader};
}


sub worker_no {
    my ($self, $number) = @_;


    if ($number) {
        $self->{worker_number} = $number;
    }

    return $self->{worker_number};
}


sub log_object {
    my ($self) = @_;

    croak 'No params for log object' if !$self->{can_create_log_object};

    return AnyEvent::TCP::Server::Log->new(
        %{$self->{_log}}
    );
}


1;

__END__
