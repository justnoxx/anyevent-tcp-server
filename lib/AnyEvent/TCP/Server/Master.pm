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
    for (1 .. $self->{_init_params}->{workers}) {
        print "spawning worker...\n";
        my $w = AnyEvent::TCP::Server::Worker->spawn({});
        push @{$self->{_workers}}, $w;
    }

    tcp_server undef, $self->{_init_params}->{port}, sub {
        my ($fh, $host, $port) = @_;

        my $h;
        # print "FDPASSING";
        # IO::FDPass::send fileno $self->{_workers}[0]->{socket}, fileno $fh;
        my $s = $self->{_workers}[0]->{writer};
        print Dumper $s;
        # warn Dumper $s->connected();
        $h = AnyEvent::Handle->new(
            fh      =>  $fh,
            on_read =>  sub {
                $h->push_write('Hello!');
                # print Dumper $self->{_workers}[0]->{socket};

                warn "FDPASS now!";
                IO::FDPass::send fileno $s, fileno $fh or warn $!;
                    # or die "unable to pass file handle: $!";;
                $h->destroy();
            }
        );
    };

    print Dumper $self;
    AnyEvent->condvar->recv();
}

1;