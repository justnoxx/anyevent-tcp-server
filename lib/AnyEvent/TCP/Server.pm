package AnyEvent::TCP::Server;

use strict;
use Carp;

use AnyEvent;
use AnyEvent::Socket;
use AnyEvent::Handle;
use IO::FDPass;

use AnyEvent::TCP::Server::Master;
use AnyEvent::TCP::Server::Worker;
use AnyEvent::TCP::Server::Watcher;

our $VERSION = 0.01;

sub new {
    my ($class, %params) = @_;

    if (!$params{process_request}) {
        croak 'Missing process_request param';
    }

    if (ref $params{process_request} ne 'CODE') {
        croak 'process_request must be a code ref';
    }

    if (!$params{port}) {
        croak 'Missing port param';
    }

    my $self = {};

    $self->{_init_params} = {
        process_request =>  $params{process_request},
        port            =>  $params{port},
        workers         =>  $params{workers} // 1,
        balancer        =>  $params{balancer} // 'round-robin',
    };
    
    bless $self, $class;
    return $self;
}


sub run {
    my ($self) = @_;

    my $master = AnyEvent::TCP::Server::Master->new($self->{_init_params});
    $master->run();
}

1;

__END__
