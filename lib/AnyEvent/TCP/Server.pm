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

our $VERSION = 0.15;

sub new {
    my ($class, %params) = @_;

    my $self = {};
    bless $self, $class;

    if (!$params{process_request}) {
        croak 'Missing process_request param';
    }

    if (ref $params{process_request} ne 'CODE') {
        croak 'process_request must be a code ref';
    }

    if (!$params{port}) {
        croak 'Missing port param';
    }

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
    
    $self->{_init_params} = {
        process_request =>  $params{process_request},
        port            =>  $params{port},
        workers         =>  $params{workers} // 1,
        balancer        =>  $params{balancer} // 'round-robin',
    };
    
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


sub daemonize {
    my ($self) = @_;

    chdir '/';
    exit if fork();
    # TODO: suppress STD*
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
