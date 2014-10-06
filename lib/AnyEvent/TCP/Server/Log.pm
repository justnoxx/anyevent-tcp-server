package AnyEvent::TCP::Server::Log;

=head1

Little log mechanism. Doc will be soon.

=cut

use strict;
use warnings;

use Data::Dumper;
use Carp 'confess';
use IO::Socket::INET;
use Exporter 'import';
use AnyEvent::TCP::Server::Utils;

our @EXPORT_OK = qw(log_client init_logger log_conf);
our $INITIATED = 0;

our $LOG_HOST = 'localhost';
our $LOG_PORT = 55555;
# my $LOG_PORT;

my $server_log;

sub init_logger {
    unless ( $server_log) {
        if (!$LOG_PORT) {
            $LOG_PORT = 55555;
        }
        my $socket = IO::Socket::INET->new(
            LocalAddr => log_host(),
            LocalPort => log_port(),
            Proto     => 'udp',
            Reuse     => 1,
        ) or confess "Logger is not spawned: $!";
        $server_log = bless \$socket => 'AnyEvent::TCP::Server::LogServer';
    }
    dbg_msg "Logger initiating";
    $INITIATED = 1;
    dbg_msg "Initiated: $INITIATED";
    return $server_log;
}

sub log_client {
    my $logger = IO::Socket::INET->new(
        PeerAddr    =>  log_host() . ':' . log_port(),
        Proto       =>  'udp',
    );

    no warnings qw/redefine/;
    
    *{AnyEvent::TCP::Server::LogClient::enabled} = sub {return 1;};
    bless \$logger => 'AnyEvent::TCP::Server::LogClient';
}


sub log_conf {
    my (%params) = @_;
    log_port ( $params{port} );
    log_host ( $params{host} );
}


sub log_host {
    my $host = shift;
    if ( $host ) {
        unless ($LOG_HOST) {
            $LOG_HOST = $host;
        }
    }
    return $LOG_HOST;
}

sub log_port {
    my $port = shift;

    if ($port) {
        unless ($LOG_PORT) {
            $LOG_PORT = $port;
        }
    }
    return $LOG_PORT;
}


package AnyEvent::TCP::Server::LogServer;

use strict;
use warnings;

sub recv {
    my $server_log = shift;
    if ( $server_log ) {
        my $log_chunk;
        $$server_log->recv($log_chunk, 4096);
        return $log_chunk;
    }
};

1;

package AnyEvent::TCP::Server::LogClient;

use strict;
use Carp;
use POSIX qw(strftime);
use Sys::Hostname qw(hostname);
use subs qw/enabled/;

use AnyEvent::TCP::Server::Log;
use AnyEvent::TCP::Server::Utils;


sub enabled {
    return 0;
}


sub splunk_log {
    return 1 unless enabled;
    my $self = shift;

    my $params;
    if (ref $_[0]) {
        $params = shift;
    }
    else {
        my %params = @_;
        $params = \%params;
    }

    my $date = strftime(q|%Y-%m-%d %H:%M:%S :> |, localtime);

    my @msg;
    for my $key (keys %$params) {
        if ($params->{$key}) {
            push @msg, "$key=$params->{$key}";
        }
    }
    my $msg = join ' ', @msg;
    $msg .= "\n";

    my $logline = $date . $msg;

    $self->send_udp_log($logline);
}

sub log {
    my ($self, @msg) = @_;
    return 1 unless enabled;
    
    my $msg = join '', @msg;

    return 1 unless $msg;
    my $logline = $self->format_log($msg);

    $self->send_udp_log($logline);
}

sub send_udp_log {
    return 1 unless enabled;
    my ( $self, $logline ) = @_;
    
    return 1 unless $logline;
    return $$self->send($logline);
}

# Jul 19 10:29:40 michael-Inspiron-7720 anacron[3118]: Job `cron.daily' terminated


sub format_log {
    my ( $self, $logline ) = @_;
    
    return unless $logline;
    my $date = strftime(q{%b %d %H:%M:%S}, localtime);
    return sprintf q|%s %s %s[%d]: %s| . "\n", $date, hostname(), $0, $$, $logline;
}


1;

__END__
