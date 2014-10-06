#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper;

use Test::More tests    =>  9;

use_ok('AnyEvent::TCP::Server');
use_ok('AETCPSRVR');
use_ok('AnyEvent::TCP::Server::AbstractWorker');
use_ok('AnyEvent::TCP::Server::LoggerWorker');
use_ok('AnyEvent::TCP::Server::Log');
use_ok('AnyEvent::TCP::Server::Master');
use_ok('AnyEvent::TCP::Server::ProcessWorker');
use_ok('AnyEvent::TCP::Server::Utils');

# check, is shortcut works
is(${AETCPSRVR::VERSION}, ${AnyEvent::TCP::Server::VERSION}, 'Shortcut works');

