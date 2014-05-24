package AnyEvent::TCP::Server::Master;

use strict;
use warnings;

use Data::Dumper;
use AnyEvent;
use AnyEvent::Socket;

use AnyEvent::Handle;
use IO::FDPass;

sub new {
    my ($class, $params) = @_;

    my $self = {
        _init_params    =>  $params,
        _workers        =>  [],
    };

    bless $self, $class;
    return $self;
}

sub run {
    my ($self) = @_;

    $0 = 'AE::TCP::Server Master';
    my $init_params = $self->{_init_params};
    $self->{workers_count} = 0;

    for (1 .. $init_params->{workers}) {
        print "spawning worker...\n";
        my $w = AnyEvent::TCP::Server::Worker->spawn($init_params);
        $w->{reader}->close();
        push @{$self->{_workers}}, $w;
    }

    $self->{workers_count} = scalar @{$self->{_workers}};

    tcp_server undef, $init_params->{port}, sub {
        my ($fh, $host, $port) = @_;

        my $balancer = $init_params->{balancer};
        $self->balance($balancer);

        warn "Next worker: ", $self->{next_worker};

        my $h;

        my $s = $self->{_workers}[$self->{next_worker}]->{writer};
        print Dumper $s;
        
        IO::FDPass::send fileno $s, fileno $fh or croak $!;

        # warn Dumper $s->connected();
        # $h = AnyEvent::Handle->new(
        #     fh          =>  $fh,
        #     on_read     =>  sub {
        #         IO::FDPass::send fileno $s, fileno $fh or croak $!;
        #         # $h->destroy();
        #     },
        #     on_error    =>  sub {
        #         warn "ONERROR!\n";
        #         $h->destroy();
        #     },
        #     on_eof      =>  sub {
        #         warn "ONDESROY!\n";
        #         $h->destroy();
        #     },
        # );
    };

    print Dumper $self;
    AnyEvent->condvar->recv();
}

# only round robin at now

sub balance {
    my ($self, $balancer) = @_;

    if (! exists $self->{next_worker}) {
        $self->{next_worker} = 0;
        return 0;
    }

    $self->{next_worker}++;
    if ($self->{next_worker} >= $self->{workers_count}) {
        $self->{next_worker} = 0;
    }

    return $self->{next_worker};
}


1;