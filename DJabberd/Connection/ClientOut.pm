package DJabberd::Connection::ClientOut;
use strict;
use base 'DJabberd::Connection';
use fields (
            'state',
            'queue',  # our DJabberd::Queue::ClientOut
            );

use IO::Handle;
use Socket qw(PF_INET IPPROTO_TCP SOCK_STREAM);
use Carp qw(croak);

sub new {
    my ($class, %opts) = @_;

    my $ip    = delete $opts{ip};
    my $endpt = delete $opts{endpoint};
    my $queue = delete $opts{queue} or croak "no queue";
    die "unknown options" if %opts;

    croak "No 'ip' or 'endpoint'\n" unless $ip || $endpt;
    $endpt ||= DJabberd::IPEndpoint->new($ip, 5222);

    #create a socket
    my $sock;
    socket $sock, PF_INET, SOCK_STREAM, IPPROTO_TCP;
    unless ($sock && defined fileno($sock)) {
        $queue->on_connection_failed("Cannot alloc socket");
        return;
    }
    IO::Handle::blocking($sock, 0);
    $ip = $endpt->addr;
    connect $sock, Socket::sockaddr_in($endpt->port, Socket::inet_aton($ip));
    $DJabberd::Stats::counter{connect}++;

    my $self = $class->SUPER::new($sock, $queue->vhost->server);
    $self->log->debug("Connecting to '$ip' for '$queue->{domain}'");
    $self->{state}     = "connecting";
    $self->{queue}     = $queue;
    $self->{vhost}     = $queue->vhost;

    Scalar::Util::weaken($self->{queue});

    return $self;
}

sub namespace {
    return "jabber:client";
}

sub start_connecting {
    my $self = shift;
    $self->watch_write(1);
}

sub on_connected {
    my $self = shift;
    print("Fooo");
    $self->start_init_stream(xmlns => "jabber:client",
                             to    => $self->{queue}->{domain});
    $self->watch_read(1);
}

sub event_write {
    my $self = shift;

    if ($self->{state} eq "connecting") {
        $self->{state} = "connected";
        $self->on_connected;
    } else {
        return $self->SUPER::event_write;
    }
}

sub on_stream_start {
    my ($self, $ss) = @_;

    $self->{in_stream} = 1;
    $self->log->debug("We got a stream back from connection $self->{id}!\n");
    #authenticate here
}

sub on_stanza_received {
    my ($self, $node) = @_;

      if ($self->xmllog->is_info) {
        $self->log_incoming_data($node);
    }


    #unless ($node->attr("{}type") eq "valid") {
    #    # FIXME: also verify other attributes
    #    warn "Not valid?\n";
    #    return;
    #}

    $self->log->debug("Connection $self->{id} established");
    $self->{queue}->on_connection_connected($self);
}

sub event_err {
    my $self = shift;
    $self->{queue}->on_connection_error($self);
    return $self->SUPER::event_err;
}

sub event_hup {
    my $self = shift;
    return $self->event_err;
}

sub close {
    my $self = shift;
    return if $self->{closed};

    $self->{queue}->on_connection_error($self);
    return $self->SUPER::close;
}

1;
