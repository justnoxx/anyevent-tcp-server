package AnyEvent::TCP::Server::Log;

=head1

Little log mechanism. Doc will be soon.

=cut

use strict;
use warnings;

use Carp 'confess';
use IO::Socket::INET;

use Exporter 'import';

our @EXPORT_OK = qw(log_client init_logger log_conf);

my $LOG_HOST = 'localhost';
my $LOG_PORT = 55555;

my $server_log;

sub init_logger {
    unless ( $server_log) {
        my $socket = IO::Socket::INET->new(
            LocalAddr => log_host(),
            LocalPort => log_port(),
            Proto     => 'udp',
            Reuse     => 1,
        ) or confess "Logger is not spawned: $!";
        $server_log = bless \$socket => 'AnyEvent::TCP::Server::LogServer';
    }
    return $server_log;
}

sub log_client {
    my $logger = IO::Socket::INET->new(
        PeerAddr    =>  log_host() . ':' . log_port(),
        Proto       =>  'udp',
    );
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
    if ($_[0]) {
        unless ($LOG_PORT) {
            $LOG_PORT = $_[0];
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

sub log {
    my ($self, @msg) = @_;

    my $msg = join '', @msg;
    my $logline = $self->format_log($msg);

    $self->send_udp_log($logline);
}

sub send_udp_log {
    my ( $self, $logline ) = @_;
    return $$self->send($logline);
}

# Jul 19 10:29:40 michael-Inspiron-7720 anacron[3118]: Job `cron.daily' terminated


sub format_log {
    my ( $self, $logline ) = @_;
    my $date = strftime(q{%b %d %H:%M:%S}, localtime);
    return sprintf q{%s %s %s[%d]: %s }, $date, hostname(), $0, $$, $logline;
}


1;

__END__
