package AnyEvent::TCP::Server::AbstractWorker;

use EV;
use Carp;
use AnyEvent;
use AnyEvent::Util qw/portable_socketpair fh_nonblocking/;
use IO::Socket::UNIX;
use IO::FDPass;

use AnyEvent::TCP::Server::Utils;
use AnyEvent::TCP::Server::Log;


sub spawn {
    my ($class, %spawn_params) = @_;

    my $spawn_params = \%spawn_params;
    
    for my $check_it (qw/number type master_does worker_does/) {
        if (!$spawn_params->{$check_it}) {
            croak "Missing required param: $check_it";
        }
    }
    no warnings qw/redefine/;
    no strict qw/refs/;

    for my $sub (qw/master_does worker_does prepare_to_spawn run/) {
        if ($spawn_params->{$sub} || ref $spawn_params->{$sub} eq 'CODE') {
            *{$class . '::' . $sub} = $spawn_params->{$sub};
        }
    }

    my $self = {};

    bless $self, $class;

    if ($spawn_params->{procname}) {
        dbg_msg 'Procname: ', $spawn_params->{procname};
        $self->{procname} = $spawn_params->{procname} . ' ' . $spawn_params->{type};
    }
    else {
        dbg_msg 'Default procname';
        $self->{procname} = 'AE::TCP::Server::AbstractWorker';
    }

    $self->worker_no($spawn_params->{number});

    $self->prepare_to_spawn($spawn_params);

    my $pid = fork();

    # master
    if ($pid) {
        $self->pid($pid);
        return $self->master_does($spawn_params);
    }
    # worker
    else {
        $self->pid($$);
        $self->worker_does($spawn_params);
        procname $self->{procname};
        $self->run();
    }
}


sub pid {
    my ($self, $pid) = @_;

    if ($pid) {
        $self->{pid} = $pid;
    }

    return $self->{pid};
}


sub seppuku {
    exit 1;
}


sub worker_no {
    my ($self, $number) = @_;


    if ($number) {
        $self->{worker_number} = $number;
    }

    return $self->{worker_number};
}


sub condvar {
    my ($self, $cv) = @_;

    if ($cv) {
        $self->{cv} = $cv;
    }
    return $self->{cv};
}


sub prepare_to_spawn {
    1;
}


sub master_does {
    1;
}


sub worker_does {
    1;
}


sub run {
    1;
}

1;

__END__

=head1 NAME

AnyEvent::TCP::Server::AbstractWorker

=head1 DESCRIPTION

Abstract worker object. You should want inherit this class.



=cut