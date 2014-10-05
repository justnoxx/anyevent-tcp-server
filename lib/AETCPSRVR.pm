=head1 NAME

AETCPSRVER

=description

Short name, alias for AnyEvent::TCP::Server;

=cut

package AETCPSRVR;
use strict;
use warnings;
use AnyEvent::TCP::Server;

use parent qw/AnyEvent::TCP::Server/;
our $VERSION = $AnyEvent::TCP::Server::VERSION;


1;

__END__


