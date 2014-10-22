package AnyEvent::TCP::Server;

use strict;
use Carp;
use POSIX qw/setuid setgid/;

use AnyEvent;
use AnyEvent::Socket;
use AnyEvent::Handle;
use IO::FDPass;

use AnyEvent::TCP::Server::Master;

use AnyEvent::TCP::Server::ProcessWorker;
use AnyEvent::TCP::Server::Utils;
use AnyEvent::TCP::Server::Log qw/log_conf log_client/;

use System::Daemon;

our $VERSION = 0.91;


sub new {
    my ($class, %params) = @_;

    my $self = {};
    bless $self, $class;
    
    # main request handler
    if (!$params{process_request}) {
        croak 'Missing process_request param';
    }

    # must be a coderef
    if (ref $params{process_request} ne 'CODE') {
        croak 'process_request must be a code ref';
    }

    if (!$params{port}) {
        croak 'Missing port param';
    }
    
    my %daemonize_options = ();
    # params for setuid and setgid
    if ($params{user} || $params{group}) {
        $self->{user} = $params{user};
        $self->{group} = $params{group};
        $daemonize_options{user} = $self->{user} if $self->{user};
        $daemonize_options{group} = $self->{group} if $self->{group};
    }

    if ($params{debug}) {
        debug 1;
    }

    if ($params{pid}) {
        $self->{master_pid} = $params{pid};
        $daemonize_options{pidfile} = $params{pid};
    }
    if ($params{daemonize} && !debug) {
        #$self->daemonize();
        $self->{daemon} = System::Daemon->new(%daemonize_options);
    }   
    if ($params{log} && ref $params{log} eq 'HASH') {
        $self->{_log} = {
            filename        =>  $params{log}->{filename},
        };
        if ($params{log}->{append}) {
            $self->{_log}->{append} = $params{log}->{append};
        }
        if ($params{log}->{port}) {
            $self->{_log}->{port} = $params{log}->{port};
            AnyEvent::TCP::Server::Log::log_conf(
                port => $self->{_log}->{port},
            );
            $AnyEvent::TCP::Server::Log::LOG_PORT = $self->{_log}->{port};
            dbg_msg "PORT: $self->{_log}->{port}";
            dbg_msg "Log port: ", $AnyEvent::TCP::Server::Log::LOG_PORT;
        }

    }

    if (!$params{procname}) {
        $params{procname} = "AE::TCP::Server";
    }
    $self->{_init_params} = {
        process_request     =>  $params{process_request},
        port                =>  $params{port},
        workers             =>  $params{workers} // 1,
        balancer            =>  $params{balancer} // 'round-robin',
        procname            =>  $params{procname},
        client_forwarding   =>  $params{client_forwarding} // 0,
    };
    
    if ($params{check_on_connect}) {
        $self->{_init_params}->{check_on_connect} = $params{check_on_connect};
    }

    if ($self->{_log}) {
        $self->{_init_params}->{_log} = $self->{_log};
    }
    return $self;
}


sub run {
    my ($self) = @_;
    
    $self->announce();
    my $master = AnyEvent::TCP::Server::Master->new($self->{_init_params});

    $master->prepare();
    if($self->{daemon}) {
        $self->{daemon}->daemonize();
    }
    $master->run();
}


sub announce {
    my ($self) = @_;

    print "Starting AnyEvent::TCP::Server.\n";
    print '=' x 80, "\n";
    print "Params are:\n";
    for my $k (keys %{$self->{_init_params}}) {
        printf "\t%s: %s\n", $k, $self->{_init_params}->{$k};
    }
    print "Enjoy.\n";
    print '=' x 80, "\n";
}


sub get_logger {
    return log_client();
}

1;

__END__

=head1 NAME

AnyEvent::TCP::Server

=head1 DESCRIPTION

High perfomance full-asynchronous pre-forking tcp server with one restriction:
B<you can't get client info(host, port, etc) inside of process_request_handler>

=head1 SYNOPSIS
    
    use AnyEvent::TCP::Server;
    # or
    # use AETCPSRCV; # as macro.

    my $ae_srvr = AnyEvent::TCP::Server->new(
        # will daemonize
        daemonize           =>  1,

        # path to pid file, which used for master process pid
        # pid               =>  '/path/to/pid/file',

        # enables advanced debug, but disables daemonize
        debug               =>  1,

        # process name, used for ps
        procname            =>  'my_cool_example',

        # port to listen
        port                =>  44444,

        # on connect subroutine, if returns false - connection will terminated.
        check_on_connect    =>  sub {
            my ($fh, $host, $port) = @_;
            return 1;
        },

        # main subroutine, it used by workers for request processing.
        process_request     =>  sub {
            my ($worker_object, $fh, $client_data) = @_;
            syswrite $fh, "[$$]: Hello!";
            close $fh;
        },

        # high-perfomance UDP logger
        # if this section does not exist, logger process will not be spawned
        log                 => {
            # logfile as is, use absolute path
            filename    =>  '/path/to/log',
            # open mode, default is 0
            append      =>  1,
            # UDP port, used for listening
            port        =>  55557,
        },
        # workers count for AETCPSRVR
        workers_count   =>  9,
    );
    
    # run server
    $ae_srvr->run();

=AUTHORS

Dmitriy @justnoxx Shamatrin

Michael @michaelshulichenko Shulichenko

=cut
