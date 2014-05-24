package AnyEvent::TCP::Server::Worker;

use strict;
use Data::Dumper;
use Carp;
use AnyEvent;
use AnyEvent::Util qw/portable_socketpair/;
use IO::Socket::UNIX;
use IO::FDPass;

sub spawn {
    my ($class, $params) = @_;

    my $self = {};
    bless $self, $class;

    ($self->{reader}, $self->{writer}) = portable_socketpair();

    my $pid = fork();

    # master
    if ($pid) {
        $self->{pid} = $pid;
        return $self;
    }
    # worker
    else {
        $self->{pid} = $$;
        $self->run();
    }
}

sub whoami {
    return Dumper shift;
}

sub run {
    my $self = shift;

    $0 = 'AE::TCP::Server::Worker';

    my $sw;

    $sw = AnyEvent->io(
        fh      =>  $self->{reader},
        poll    =>  'r',
        cb      =>  sub {
            warn "CALLBACK!\n";
            my $fd = IO::FDPass::recv fileno $self->{reader};
            # print Dumper $fh;
            open my $fh, "+<&=$fd" or croak "unable to convert file descriptor to handle: $!";
            warn "FH: " . Dumper $fh;
            my $h;
            $h = AnyEvent::Handle->new(fh=>$fh)->push_write("ATATA");

        },
    );
    AnyEvent->condvar->recv();
}

1;

__END__
