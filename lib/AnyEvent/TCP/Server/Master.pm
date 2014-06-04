package AnyEvent::TCP::Server::Master;

use strict;
# use warnings;
use warnings FATAL => 'all';

use Carp;
use Data::Dumper;
use AnyEvent;
use AnyEvent::Socket;
use System::Process;

use AnyEvent::Handle;
use IO::FDPass;

use AnyEvent::TCP::Server::Worker;

use POSIX;


sub new {
    my ($class, $params) = @_;

    my $self = {
        _init_params    =>  $params,
        _workers        =>  {},
        assoc           =>  {},
        firstrun        =>  1,
        max_workers     =>  $params->{workers},
    };

    bless $self, $class;
    return $self;
}


sub prepare {
    my ($self) = @_;

    my $init_params = $self->init_params();
    if ($self->{firstrun}) {
        %{$self->{respawn}} = map {$_, 1} (1 .. $init_params->{workers});
    }
    warn 'prepared for respawn: ', Dumper $self->{respawn};
}


sub procname {
    return 1;
}


sub run {
    my ($self) = @_;

    $self->{_cv} = AnyEvent->condvar();

    $0 = 'AE::TCP::Server::Master';
    
    my $init_params = $self->init_params();

    $self->{workers_count} = 0;

    

    # run worker
    for my $key (sort {$a <=> $b} keys %{$self->{respawn}}) {
        print "spawning worker: $key\n";
        my $w = AnyEvent::TCP::Server::Worker->spawn($init_params);

        $w->{worker_number} = $_;

        $self->add_worker($w, $key);
        $self->numerate($w->{pid}, $key);
    }

    warn "RESPAWNED!";

    $self->{respawn} = {};

    warn "REGISTERING SIGNALS";

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

    warn "SIGNALS REGISTERED!";
    
    # exit 1;


    $self->set_watchers();

    
    my $guard;
    $guard = tcp_server undef, $init_params->{port}, sub {
        my ($fh, $host, $port) = @_;

        warn "Connection accepted";
        
        my $current_worker = $self->next_worker();
        my $cw = $current_worker;

        warn "Next worker choosed: $self->{next_worker_number}";

        my $s = $cw->{writer};
        # пробросим файловый дескриптор воркеру
        IO::FDPass::send fileno $s, fileno $fh or croak $!;

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

    $self->{watchers} = [];

    for my $w (values %{$self->{_workers}}) {
        push @{$self->{watchers}}, AnyEvent->child(
            pid => $w->{pid},
            cb  => sub {
                undef $self->{timer};
                $self->{timer} = AnyEvent->timer(
                    after   =>  0.1,
                    cb      =>  sub {
                        warn "TIME IS UP!";
                        warn "For respawn: ", Dumper $self->{respawn};
                        $self->{_cv}->send('RESPAWN');
                    }
                );

                my $number = $self->number($w->{pid});
                warn "number: $number";
                # warn Dumper $self;
                $self->{respawn}->{$number} = 1;
                warn "OMG!111 pid $w->{pid} DIED!!111";
            },
        );
    }
}


sub process_signal {
    my ($self, $signal) = @_;

    warn "Lets kill: ", Dumper $self->{_workers};
    for my $w (values %{$self->{_workers}}) {
        warn "[$$]: GONNA KILL: $w->{pid}!";
        kill POSIX::SIGTERM, $w->{pid};
    }
    return 1;
}

# sub next_worker {}

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
