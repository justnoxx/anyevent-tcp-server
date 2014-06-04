package AnyEvent::TCP::Server::Worker;

use strict;
use warnings;
# use diagnostics;

use EV;

use Data::Dumper;
use Carp;
use AnyEvent;
use AnyEvent::Util qw/portable_socketpair fh_nonblocking/;
use IO::Socket::UNIX;
use IO::FDPass;
use Storable qw/thaw/;

use AnyEvent::TCP::Server::Utils;


sub spawn {
    my ($class, $params) = @_;

    my $self = {
        process_request => $params->{process_request},
    };
    bless $self, $class;

    ($self->{reader}, $self->{writer}) = portable_socketpair();
    ($self->{rdr}, $self->{wrtr}) = portable_socketpair();

    fh_nonblocking($self->{reader}, 1);
    fh_nonblocking($self->{writer}, 1);

    fh_nonblocking($self->{rdr}, 1);
    fh_nonblocking($self->{wrtr}, 1);
    
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


# возможность для воркера выстрелить себе в ногу
sub sepukku {
    exit 1;
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

            open my $fh, "+<&=$fd" or do {
                dbg_msg "Unable to convert file descriptor to handle: $!";
                # самоуничтожаемся, если дескриптор битый - лучше так, а мастер потом разберется
                # а если мастер сдох, то никто это не обработает и все опять в выигрыше
                $self->sepukku();
            };

            my $sub = $self->{process_request};

            my $ch;
            $ch = AnyEvent::Handle->new(
                fh          =>  $self->{rdr}, 
                on_read     =>  sub {
                    my $client = thaw($ch->{rbuf});
                    $sub->($self, $fh, $client);
                    $ch->destroy();
                },
            );
        },
    );
    # EV::run();
    # $self->{loop}
    AnyEvent->condvar->recv();
}


sub rdr_socket {
    my $self = shift;
    return $self->{reader};
}


1;

__END__
