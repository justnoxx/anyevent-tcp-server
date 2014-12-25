package AnyEvent::TCP::Server::Utils;

require Exporter;
our @ISA = qw/Exporter/;

use strict;
use warnings;
use Carp;

use subs qw /debug now dbg_msg procname/;
our @EXPORT = qw/now debug dbg_msg procname/;


my $NOW_FORMAT = '[%d-%02d-%02d %02d:%02d:%02d][%s]';

my $DEBUG = 0;
my $LOG_FILE;

sub now {
    my ($sec,
        $min,
        $hour,
        $mday,
        $mon,
        $year,
        $wday,
        $yday,
        $isdst
    ) = localtime(time);

    $year += 1900;
    $mon++;

    return sprintf ($NOW_FORMAT, $year, $mon, $mday, $hour, $min, $sec, $$);
}


sub dbg_msg {
    return 1 unless debug;
    my $msg = join '', @_;

    return 1 unless $msg;

    if ($msg !~ m!\s$!s) {
        $msg .= "\n";
    }
    $msg  = now . "\t" . $msg;
    if (!$LOG_FILE) {
        warn $msg;    
    }
    else {
        # TODO: add async log
        # ...;
        # for compat
        warn $msg;
    }
    return 1;
}


sub debug {
    my $param = shift;

    $DEBUG = $param if $param;
    return $DEBUG; 
}


sub log_file {
    my $param = shift;

    $LOG_FILE = $param if $param;
    return $LOG_FILE; 
}


sub procname {
    my ($procname) = @_;

    unless ($procname) {
        croak "Can't set procname without procname param";
    }
    $0 = $procname;

    return 1;
}


1;

__END__
