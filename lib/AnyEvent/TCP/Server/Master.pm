package AnyEvent::TCP::Server::Master;

use strict;
use warnings;

use Data::Dumper;
use AnyEvent::Socket;

use AnyEvent::Handle;
use IO::FDPass;

sub new {
	my ($class, $params) = @_;

	my $self = {
		_init_params => $params,
	};
	bless $self, $class;
	return $self;
}

sub run {
	my ($self) = @_;

	tcp_server undef, $self->{_init_params}->{port}, sub {
		my ($fh, $host, $port) = @_;

		my $h;
		$h = AnyEvent::Handle->new(fh=>$fh, sub {
			$fh->push_write('Hello!');
		});
	}
	AnyEvent->condvar->recv();
}

1;