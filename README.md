# AnyEvent::TCP::Server

## NAME

AnyEvent::TCP::Server

## DESCRITPION

High perfomance pre-forking full-asynchronous tcp server. One restriction:
you can't get client info inside process\_request subroutine.

## METHODS

**new** creates AE::TCP::Server object. Params:

 - workers \- workers count
 - pid \- path to pid file
 - daemonize \- daemonize or not
 - debug \- debug mode
 - user \- user for setuid
 - group \- group for setgid
 - procname \- name of process for ps
 - port \- port to listen. Unix sockets not supported right now
 - process\_request \- subroutine ref for processing requests

**run** runs connection manager and blocks.

## SYNOPSIS

Little example, how to use it:

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
