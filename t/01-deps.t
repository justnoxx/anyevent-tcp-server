#!/usr/bin/env perl
use strict;
use Test::More tests => 14;
open STDERR, '>>', '/dev/null';
# let's check, are dependencies is available
use_ok('IO::FDPass');
use_ok('System::Process');
use_ok('System::Daemon');
use_ok("AnyEvent");
use_ok("AnyEvent::Util");
use_ok("AnyEvent::Handle");
use_ok("AnyEvent::Socket");
use_ok("AnyEvent::HTTP");
use_ok("EV");
use_ok("IO::Socket::UNIX");
use_ok("IO::Socket::INET");
use_ok("Cwd");
# let's check versions.

require System::Process;
import  System::Process;

require System::Daemon;
import  System::Daemon;

ok($System::Daemon::VERSION >= 0.12, "System::Daemon version $System::Daemon::VERSION is suitable");
ok($System::Process::VERSION >= 0.17, "System::Process version $System::Process::VERSION is suitable");

