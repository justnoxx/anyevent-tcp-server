# AnyEvent::TCP::Server

## NAME

AnyEvent::TCP::Server

## DESCRITPION

Simple fork master-worker proof of concept. Async master + async workers.
After accepting a connection AnyEvent::TCP::Server::Master sending opened file
descriptor to worker. Worker executes user's subroutine

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
