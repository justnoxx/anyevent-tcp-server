package AnyEvent::TCP::Server::Master;

use strict;
use warnings;
use diagnostics;

use Carp;
use Data::Dumper;
use AnyEvent;
use AnyEvent::Socket;

use AnyEvent::Handle;
use IO::FDPass;

use AnyEvent::TCP::Server::Worker;

use POSIX;

# my @watchers;
local $SIG{'INT'} = sub {
    warn "INTERRUPTED!!111\n";
};

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

        my $balancer = $init_params->{balancer};
        $self->balance($balancer);

        my $h;

        my $s = $self->{_workers}[$self->{next_worker}]->{writer};
        # print Dumper $s;
        
        # пробросим файловый дескриптор воркеру
        IO::FDPass::send fileno $s, fileno $fh or croak $!;

    };

    $self->recursive_cv();
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
        # warn "GONNA SET WATCHER FOR ", Dumper $w;
        push @{$self->{watchers}}, AnyEvent->child(
            pid => $w->{pid},
            cb  => sub {
                warn 'RESPAWNING';
                my $assoc = $self->{assoc}->{$w->{pid}};
                $self->{_cv}->send({assoc => $assoc});
            },
        );
    }
}


sub process_signal {
    my ($self, $signal) = @_;

    for my $w (@{$self->{_workers}}) {
        warn "GONNA KILL: $w->{pid}!";
        kill POSIX::SIGTERM, $w->{pid};
    }
    return 1;
}


sub spawn_worker {
    my ($self) = @_;

}


sub recursive_cv {
    my $self = shift;

    my $init_params = $self->{_init_params};

    my $msg = $self->{_cv}->recv();
    if (ref $msg eq 'HASH') {
        # warn Dumper $msg;
        my $assoc = $msg->{assoc};
        warn "Assoc: $assoc";
        undef $self->{_cv};

        $assoc--;

        $self->{_workers}->[$assoc] = 
            AnyEvent::TCP::Server::Worker->spawn($init_params);
        $self->set_watchers();
        $self->{_cv} = AnyEvent->condvar();

        $self->recursive_cv();
    }
}

1;
