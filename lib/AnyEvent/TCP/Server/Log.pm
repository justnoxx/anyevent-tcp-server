package AnyEvent::TCP::Server::Log;

=head1

Little log mechanism. Doc will be soon.

=cut

use strict;
use warnings;

use AnyEvent;
use AnyEvent::Handle;

use Carp;
use Fcntl qw/:seek/;
use AnyEvent::IO qw/:DEFAULT :flags/;


my $handle = undef;
my %stats;

my @tokens = (
    '%sec',     # second    # 0
    '%min',     # minute    # 1
    '%hour',    # hour      # 2
    '%mday',    # mday      # 3
    '%mon',     # mon       # 4
    '%year'     # year      # 5
);


sub new {
    my ($class, %params) = @_;

    my $params = \%params;
    my $self = {};

    $self->{filename} = $params->{filename} // 'STDOUT';

    unless ($params->{format_string}) {
        croak "Can't use log without format_string param";
    }

    $self->{format_string} = $params->{format_string};

    $self->{umask} = $params->{umask} // 0600;

    bless $self, $class;

    $self->parse_format_string();
    return $self;
}


sub parse_format_string {
    my ($self, $params) = @_;

    unless ($self->{format_string}) {
        croak "Can't parse nothing!";
    }

    $self->{format_string} =~ s/%n/\n/s;

    my @slice_array = ();
    my $fs = $self->{format_string};

    # TODO: переделать механизм парсинга строки
    for (my $i = 0; $i < scalar @tokens; $i++) {
        my $token = $tokens[$i];
        if ($fs =~ s/$token/%s/s) {
            unshift @slice_array, $i;
        }
    }

    $self->{parsed_format_string} = $fs;

    $self->{transform_sub} = sub {
        my ($msg) = @_;
        
        my $logline = $fs;
        $logline =~ s/%msg/$msg/gs;
        my @now = get_now();
        $logline = sprintf $logline, @now[@slice_array];
        return $logline;
    };

}


sub log {
    my ($self, @msg) = @_;

    croak unless ($self->{transform_sub});

    my $msg = join '', @msg;

    my $logline = $self->{transform_sub}->($msg);

    $self->write_log($logline);
}


sub write_log {
    my $self = shift;
    my $logline = shift;

    if ($self->{filename} =~ m/STDOUT/s) {
        print $logline
        return 1;
    }

    if ($handle && !-e $self->{filename}) {
        $handle->destroy();
        $handle = undef;
    }

    if (!check_file($self->{filename})) {
        $handle->destroy() if $handle;
        $handle = undef;
    }

    if ($handle) {
        _push_write($handle, $self->{filename}, $logline);
        return 1;
    }

    # если таки хендлера нет, мы его создадим
    aio_open $self->{filename}, O_WRONLY | O_APPEND | O_CREAT, $self->{umask}, sub {
        my ($fh) = @_;

        $handle ||= AnyEvent::Handle->new(
            fh          =>  $fh,
            on_error    =>  sub {
                $handle->destroy();
                $handle = undef;
            },
            on_eof      =>  sub {
                $handle->destroy();
                $handle = undef;
            },
            on_close    =>  sub {
                $handle->destroy();
                $handle = undef;
            },
        );    
        
        my $ae_h;
        $ae_h = $handle;
        _push_write($ae_h, $self->{filename}, $logline);
    };
    return 1;
}


sub check_file {
    my $fname = shift;

    return 1 if (!exists $stats{last_stat}->{$fname} && !exists $stats{current_stat}->{$fname});

    $stats{last_stat}->{$fname} ||= 0;
    $stats{current_stat}->{$fname} ||= 0;

    if ($stats{last_stat}->{$fname} == $stats{current_stat}->{$fname}) {
        return 0;
    }

    return 1;
}


sub get_now {
    my ($self, $params) = @_;

    my $dh;

    my @arr = (
        $dh->{sec},
        $dh->{min},
        $dh->{hour},
        $dh->{mday},
        $dh->{mon},
        $dh->{year},
        $dh->{wday},
        $dh->{yday},
        $dh->{isdst}
    ) = localtime(time);


    if (wantarray) {

        $arr[4]++;
        $arr[5] += 1900;
        for (0 .. 5) {
            $arr[$_] = sprintf('%02d', $arr[$_]);
        }
        return @arr;
    }
    else {
        $dh->{year} += 1900;
        $dh->{mon}++;

        for (qw/mon mday hour min sec/) {
            $dh->{$_} = sprintf('%02d', $dh->{$_});
        }
        return $dh;
    }
}


sub _push_write {
    my ($handle, $fname, $message) = @_;

    # как-то так
    seek $handle->{fh}, 0, SEEK_END;

    $stats{last_stat}->{$fname} = -s $fname;
    $handle->push_write($message);
    $stats{current_stat}->{$fname} = -s $fname;
}


1;

__END__
