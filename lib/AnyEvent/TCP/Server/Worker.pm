package AnyEvent::TCP::Server::Worker;

use strict;
use warnings;
use diagnostics;

use Data::Dumper;
use Carp;
use AnyEvent;
use AnyEvent::Util qw/portable_socketpair fh_nonblocking/;
use IO::Socket::UNIX;
use IO::FDPass;

sub spawn {
    my ($class, $params) = @_;

    my $self = {
        process_request => $params->{process_request},
    };
    bless $self, $class;

    ($self->{reader}, $self->{writer}) = portable_socketpair();

    fh_nonblocking($self->{reader}, 1);
    fh_nonblocking($self->{writer}, 1);
    
    my $pid = fork();

    # master
    if ($pid) {
        # в мастере reader сокет не нужен, пока-что
        $self->{reader}->close();
        $self->{pid} = $pid;
        return $self;
    }
    # worker
    else {
        $self->{writer}->close();
        $self->{pid} = $$;
        $self->run();
    }
}

sub whoami {
    return Dumper shift;
}


sub pid {
    my $self = shift;

    return $self->{pid};
}


sub run {
    my ($self) = @_;

    $0 = 'AE::TCP::Server::Worker';

    my $sw;

    $sw = AnyEvent->io(
        fh      =>  $self->{reader},
        poll    =>  'r',
        cb      =>  sub {
            my $fd = IO::FDPass::recv fileno $self->{reader};
            open my $fh, "+<&=$fd" or warn "unable to convert file descriptor to handle: $!";
            my $h;

            $h = AnyEvent::Handle->new(
                fh  =>  $fh
            );

            my $sub = $self->{process_request};
            $sub->($self, $fh, $h);
            # $h = AnyEvent::Handle->new(fh=>$fh)->push_write($whoami);

        },
    );
    AnyEvent->condvar->recv();
}

1;

__END__
