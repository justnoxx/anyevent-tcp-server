package AnyEvent::TCP::Server::Master;

use strict;
use warnings;

use Carp;
use Data::Dumper;
use AnyEvent;
use AnyEvent::Socket;
use AnyEvent::Handle;
use IO::FDPass;

use AnyEvent::TCP::Server::Worker;
use AnyEvent::TCP::Server::Utils;

use POSIX;


sub new {
    my ($class, $params) = @_;

    my $self = {
        _init_params        =>  $params,
        _workers            =>  {},
        assoc               =>  {},
        firstrun            =>  1,
        client_forwarding   =>  0,
        max_workers         =>  $params->{workers},
        procname            =>  'AE::TCP::Server::Master',
    };

    bless $self, $class;

    if ($self->{_init_params}->{procname}) {
        $self->{procname} = $self->{_init_params}->{procname} . ' master';
    }

    if ($self->{_init_params}->{client_forwarding}) {
        $self->{client_forwarding} = 1;
        croak "Client forwarding disabled right now. Maybe, it will be available soon.";
    }

    if ($params->{check_on_connect}) {
        croak 'check_on_connect must be a CODE ref' if ref $params->{check_on_connect} ne 'CODE';
        $self->{check_on_connect} = $params->{check_on_connect};
    }

    if ($self->{_init_params}->{_log}) {
        $self->{_log} = $self->{_init_params}->{_log};
    }
    
    return $self;
}


sub prepare {
    my ($self) = @_;

    my $init_params = $self->init_params();
    if ($self->{firstrun}) {
        %{$self->{respawn}} = map {$_, 1} (1 .. $init_params->{workers});
    }

    $self->{firstrun} = 0;

    dbg_msg 'prepared for respawn: ', Dumper $self->{respawn};
}


sub run {
    my ($self) = @_;

    $self->{_cv} = AnyEvent->condvar();

    procname $self->{procname};

    # $0 = 'AE::TCP::Server::Master';
    
    my $init_params = $self->init_params();

    $self->{workers_count} = 0;

    # run worker
    for my $key (sort {$a <=> $b} keys %{$self->{respawn}}) {
        dbg_msg "spawning worker: $key\n";
        my $w = AnyEvent::TCP::Server::Worker->spawn($init_params, $key);

        $self->add_worker($w, $key);
        $self->numerate($w->{pid}, $key);
    }

    dbg_msg "Workers spawned";

    $self->{respawn} = {};

    $self->{sigterm} = undef;
    $self->{sigterm} = AnyEvent->signal(
        signal  =>  'TERM',
        cb      =>  sub {
            $self->process_signal('TERM');
            exit 1;
        },
    );


    $self->{sigint} = undef;
    $self->{sigint} = AnyEvent->signal(
        signal  =>  'INT',
        cb      =>  sub {
            $self->process_signal('INT');
            exit 1;
        },
    );

    $self->set_watchers();

    
    my ($guard, $sub);
    if ($self->{check_on_connect}) {
        $sub = $self->{check_on_connect};
    }

    eval {
        $guard = tcp_server undef, $init_params->{port}, sub {
            my ($fh, $host, $port) = @_;

            if ($sub) {
                my $resp = $sub->($fh, $host, $port);
                return $resp unless $resp;
            }

            dbg_msg "Connection accepted";
            
            my $current_worker = $self->next_worker();
            my $cw = $current_worker;

            dbg_msg "Next worker choosed: $self->{next_worker_number}";

            my $s = $cw->{writer};
            # syswrite $s, "GET";
            # пробросим файловый дескриптор воркеру
            IO::FDPass::send fileno $s, fileno $fh or croak $!;
        };
        1;
    } or do {
        $self->reap_children();
        croak "Error occured: $@\n";
    };
    
    my $cmd = $self->{_cv}->recv();
    $self->{_cv} = undef;
    $guard = undef;

    if ($cmd eq 'RESPAWN') {
        # насколько мне известно, это единственный способ грохнуть хэндлер
        # сигнала в мастер процессе.
        $SIG{INT} = $SIG{TERM} = 'DEFAULT';

        $self->run();
    }
    else {
        $self->reap_children();
        exit 1;
    }
}


sub next_worker {
    my ($self) = @_;

    if (!$self->{next_worker_number}) {
        $self->{next_worker_number} = 1;
        return $self->get_worker(1);
    }

    $self->{next_worker_number}++;

    if ($self->{next_worker_number} > $self->{max_workers}) {
        delete $self->{next_worker_number};
        return $self->next_worker();
    }

    return $self->get_worker($self->{next_worker_number});
}


# only round robin at now
sub balance {
    my ($self, $balancer) = @_;

    if (! exists $self->{next_worker}) {
        $self->{next_worker} = 1;
        return 0;
    }

    $self->{next_worker}++;
    if ($self->{next_worker} >= $self->{workers_count}) {
        $self->{next_worker} = 0;
    }
    return $self->{next_worker};
}


sub set_watchers {
    my ($self) = @_;
    
    my $workers = $self->{_workers};
    my $init_params = $self->{_init_params};

    $self->{watchers} = {};

    for my $w (values %{$self->{_workers}}) {
        my $worker_no = $w->worker_no();
        # ставим вотчер по номеру
        $self->{watchers}->{$worker_no} = AnyEvent->child(
            pid => $w->{pid},
            cb  => sub {
                # ошибка времени выполнения
                if ($_[1] == 3328) {
                    dbg_msg "Compile time error. Shut down";
                    $self->reap_children();
                    exit 0;
                }
                elsif ($_[1] == 25088) {
                    dbg_msg 'bind error';
                    $self->reap_children();
                    exit 0;
                }

                undef $self->{timer};
                $self->{timer} = AnyEvent->timer(
                    after   =>  0.1,
                    cb      =>  sub {
                        dbg_msg "Workers for respawn: ", Dumper $self->{respawn};
                        $self->{_cv}->send('RESPAWN');
                    }
                );

                my $number = $self->number($w->{pid});
                $self->{respawn}->{$number} = 1;
                dbg_msg "Process with $w->{pid} died";
            },
        );
    }
}


sub process_signal {
    my ($self, $signal) = @_;

    $self->reap_children();
    return 1;
}


sub reap_children {
    my ($self) = @_;

    dbg_msg "Reaper is coming.";
    for my $w (values %{$self->{_workers}}) {
        dbg_msg "[$$]: Reaping: $w->{pid}!";
        kill POSIX::SIGTERM, $w->{pid};
    }
    return 1;
}


sub init_params {
    my ($self, $params) = @_;

    unless ($params) {
        return $self->{_init_params}
    }

    $self->{_init_params} = $params;
    return $params;
}


sub add_worker {
    my ($self, $worker, $number) = @_;

    if (!$worker || !$number) {
        croak 'Missing params for add_worker subroutine';
    }
    
    $self->{_workers}->{$number} = $worker;
}


sub get_worker {
    my ($self, $number) = @_;

    croak 'Missing argument for get_worker' unless $number;

    return $self->{_workers}->{$number};
}


sub numerate {
    my ($self, $pid, $number) = @_;

    $self->{_pids}->{$pid} = $number;
    $self->{_numbers}->{$number} = $pid;
    return 1;
}


sub denumerate {
    my ($self, $pid) = @_;

    delete $self->{_pids}->{$pid};
    return 1;
}


sub number {
    my ($self, $pid) = @_;

    return $self->{_pids}->{$pid};
}


sub pid {
    my ($self, $number) = @_;

    return $self->{_numbers}->{$number};
}


1;


__END__
