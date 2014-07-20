package AnyEvent::TCP::Server::Log;

=head1

Little log mechanism. Doc will be soon.

=cut

use strict;
use warnings;

use Carp;
use POSIX qw(strftime);
use Sys::Hostname qw(hostname);
use IO::Socket::INET;

sub new {
    my ($class, %params) = @_;

    my $self = {};

    $self->{udp_socket} = new IO::Socket::INET(
        PeerAddr    =>  q{127.0.0.1:5140},
        Proto       =>  q{udp},
    );

    return bless $self, $class;
}

sub log {
    my ($self, $msg) = @_;

    my $logline = $self->format_log($msg);

    $self->send_udp_log($logline);
}

sub send_udp_log {
    my ( $self, $logline ) = @_;
    return $self->{udp_socket}->send($logline);
}

# Jul 19 10:29:40 michael-Inspiron-7720 anacron[3118]: Job `cron.daily' terminated


sub format_log {
    my ( $self, $logline ) = @_;
    my $date = strftime(q{%b %d %H:%M:%S}, localtime);
    return sprintf q{%s %s %s[%d]: %s }, $date, hostname(), $0, $$, $logline;
}


1;

__END__
