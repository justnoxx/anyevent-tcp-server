package AnyEvent::TCP::Server;

use strict;
use Carp;
use POSIX qw/setuid setgid/;

use AnyEvent;
use AnyEvent::Socket;
use AnyEvent::Handle;
use IO::FDPass;

use AnyEvent::TCP::Server::Master;
use AnyEvent::TCP::Server::Worker;
use AnyEvent::TCP::Server::Utils;


our $VERSION = 0.60;


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

    # params for setuid and setgid
    if ($params{user} || $params{group}) {
        $self->{user} = $params{user};
        $self->{group} = $params{group};
        $self->apply_rights_change();
    }

    if ($params{debug}) {
        debug 1;
    }

    if ($params{daemonize}) {
        $self->daemonize();
    }

    if ($params{pid}) {
        $self->{master_pid} = $params{pid};
        $self->do_pid();
    }
    
    if ($params{log} && ref $params{log} eq 'HASH') {
        $self->{_log} = {
            filename        =>  $params{log}->{filename},
            format_string   =>  $params{log}->{format_string} // croak "Can't init log params without format_string",
        };
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


# daemonize section
sub daemonize {
    my ($self) = @_;

    unless (debug) {
        open STDIN, '/dev/null'     or croak "Can't read /dev/null: $!";
        open STDOUT, '>>/dev/null'  or croak "Can't write to /dev/null: $!";
        open STDERR, '>>/dev/null'  or croak "Can't write to /dev/null: $!";
    }

    chdir '/';
    exit if fork();
}


sub do_pid {
    my ($self, $pidfile) = @_;

    $pidfile ||= $self->{master_pid};

    if (-e $pidfile) {
        if (-s $pidfile) {
            open PID, $pidfile or die "Can't open $pidfile for read: $!";
            my $pid = <PID>;
            close PID;

            if (kill 0, $pid) {
                dbg_msg "Can't overwrite pid of alive process...";
                exit 1;
            }
        }
    }
    open PID, '>', $pidfile or die "Can't open $pidfile for write: $!";
    print PID $$;
    close PID;
    return 1;
}


sub apply_rights_change {
    my $options = shift;

    if ($options->{group}) {
        dbg_msg "Gonna setgid";
        my $gid = getpwnam($options->{group});
        
        unless ($gid) {
            croak "Group $options->{group} does not exists.";
        }

        unless (setgid($gid)) {
            dbg_msg "Can't setgid $gid: $!";
            croak "Can't setgid $gid: $!";
        }
    }

    if ($options->{user}) {
        dbg_msg "Gonna setuid";
        my $uid = getpwnam($options->{user});

        unless ($uid) {
            croak "User $options->{user} does not exists.";
        }

        unless (setuid($uid)) {
            dbg_msg "Can't setuid $uid: $!";
            croak "Can't setuid $uid: $!";
        }
    }

    return 1;
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
    my $ae_srvr = AnyEvent::TCP::Server->new(
        # will daemonize
        daemonize           =>  1,

        # path to pid file, which used for master process pid
        # pid               =>  '/path/to/pid/file',

        # enables advanced debug
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
            my ($worker_object, $fh, undef) = @_;
            syswrite $fh, "[$$]: Hello!";
            close $fh;
        },
    );
    
    # run server
    $ae_srvr->run();


=cut
