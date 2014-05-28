package AnyEvent::TCP::Server::Master;

use strict;
use warnings;

use Carp;
use Data::Dumper;
use AnyEvent;
use AnyEvent::Socket;
use System::Process;

use AnyEvent::Handle;
use IO::FDPass;

use AnyEvent::TCP::Server::Worker;

use POSIX;

my (@got, @workers, @watchers);
sub new {
    my ($class, $params) = @_;

    my $self = {
        _init_params    =>  $params,
        _workers        =>  [],
        assoc           =>  {},
    };

    bless $self, $class;
    return $self;
}


sub run {
    my ($self) = @_;

    $self->{_cv} = AnyEvent->condvar();

    $0 = 'AE::TCP::Server::Master';
    my $init_params = $self->{_init_params};
    $self->{workers_count} = 0;

    # run worker
    for (1 .. $init_params->{workers}) {
        print "spawning worker...\n";
        my $w = AnyEvent::TCP::Server::Worker->spawn($init_params);

        $w->{worker_number} = $_;

        $self->{assoc}->{$w->{pid}} = $_;

        push @{$self->{_workers}}, $w;
    }


    $self->set_watchers();
    $self->{workers_count} = scalar @{$self->{_workers}};

    my $sigterm; $sigterm = AnyEvent->signal(
        signal  =>  'TERM',
        cb      =>  sub {
            $self->process_signal('TERM');
            exit 1;
        },
    );

    my $sigint; $sigint = AnyEvent->signal(
        signal  =>  'INT',
        cb      =>  sub {
            $self->process_signal('INT');
            exit 1;
        },
    );

    tcp_server undef, $init_params->{port}, sub {
        my ($fh, $host, $port) = @_;

        warn "Connection accepted";
        my $balancer = $init_params->{balancer};
        $self->balance($balancer);

        my $h;
        warn "Next worker choosed: $self->{next_worker}";
        warn scalar @{$self->{_workers}};
        my $s = $self->{_workers}[$self->{next_worker}]->{writer};
        # print Dumper $s;
        
        # warn Dumper $self->{_workers};
        warn Dumper $s;
        # пробросим файловый дескриптор воркеру
        IO::FDPass::send fileno $s, fileno $fh or croak $!;

    };
    $self->{_cv}->recv();
    # $self->recursive_cv();
    # print Dumper $self;


    exit 1;
}

# only round robin at now

sub balance {
    my ($self, $balancer) = @_;

    if ($balancer eq 'round-robin') {
        if (! exists $self->{next_worker}) {
            $self->{next_worker} = 0;
            return 0;
        }

        $self->{next_worker}++;
        if ($self->{next_worker} >= $self->{workers_count}) {
            $self->{next_worker} = 0;
        }
    }
    return $self->{next_worker};
}

sub set_watchers {
    my ($self) = @_;
    
    my $workers = $self->{_workers};
    my $init_params = $self->{_init_params};

    $self->{watchers} = [];

    for my $w (@{$self->{_workers}}) {
        push @{$self->{watchers}}, AnyEvent->child(
            pid => $w->{pid},
            cb  => sub {
                undef $self->{timer};
                $self->{timer} = AnyEvent->timer(
                    after   =>  1,
                    cb      =>  sub {
                        warn Dumper $self->{got};
                        for my $g (@{$self->{got}}) {
                            my $new_worker = AnyEvent::TCP::Server::Worker->spawn($init_params);

                            my $assoc = $g->{assoc};
                            $self->{assoc}->{$new_worker->{pid}} = $assoc;
                            $new_worker->{worker_number} = $assoc;

                            $assoc--;

                            $self->{_workers}->[$assoc] = $new_worker;
                        }
                        $self->{got} = [];
                        $self->set_watchers();
                        $self->{next_worker} = 0;
                    }
                );

                my $assoc = $self->{assoc}->{$w->{pid}};

                push @{$self->{got}}, {assoc => $assoc};

                warn "OMG!111 pid $w->{pid} DIED!!111";

            },
        );
    }
}


sub process_signal {
    my ($self, $signal) = @_;

    warn "Lets kill: ", Dumper $self->{_workers};
    for my $w (@{$self->{_workers}}) {
        warn "GONNA KILL: $w->{pid}!";
        kill POSIX::SIGTERM, $w->{pid};
    }
    return 1;
}


sub spawn_worker {
    my ($self) = @_;

}


1;
