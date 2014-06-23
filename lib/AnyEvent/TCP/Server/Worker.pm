package AnyEvent::TCP::Server::Worker;

use strict;
use warnings;

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


# worker can commit a suicide
sub sepukku {
    exit 1;
}


sub run {
    my ($self) = @_;

    procname $self->{procname};

    my $sw;

    no warnings 'redefine';
    *{AnyEvent::TCP::Server::Worker::process_request} = $self->{process_request};
    use warnings 'redefine';

    $sw = AnyEvent->io(
        fh      =>  $self->{reader},
        poll    =>  'r',
        cb      =>  sub {

            # receive file descriptor from master
            my $fd = IO::FDPass::recv fileno $self->{reader};

            open my $fh, "+<&=$fd" or do {
                dbg_msg "Unable to convert file descriptor to handle: $!";
                # self-kill, if file descriptor is broken. Master will handle it.
                # If master dead, there are no one, who cares.
                $self->sepukku();
            };
            
            # process request with user subroutine
            $self->process_request($fh, {});
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


sub process_request {
    return 1;
}

1;

__END__
