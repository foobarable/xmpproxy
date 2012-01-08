package DJabberd::Connection::ClientOut;
use strict;
use base 'DJabberd::Connection';
use fields (
	'state',
	'queue',    # our DJabberd::Queue::ClientOut
);

use IO::Handle;
use Socket qw(PF_INET IPPROTO_TCP SOCK_STREAM);
use Carp qw(croak);
use DJabberd::IQ;
use DJabberd::Message;
use DJabberd::Presence;
use DJabberd::Stanza::SASL;

my %element2class = (
	"{jabber:client}iq"                           => 'DJabberd::IQ',
	"{jabber:client}message"                      => 'DJabberd::Message',
	"{jabber:client}presence"                     => 'DJabberd::Presence',
	"{urn:ietf:params:xml:ns:xmpp-tls}starttls"   => 'DJabberd::Stanza::StartTLS',
	"{urn:ietf:params:xml:ns:xmpp-sasl}challenge" => 'DJabberd::Stanza::SASL',
	"{urn:ietf:params:xml:ns:xmpp-sasl}failure"   => 'DJabberd::Stanza::SASL',
	"{urn:ietf:params:xml:ns:xmpp-sasl}success"   => 'DJabberd::Stanza::SASL',
	"{http://etherx.jabber.org/streams}features"  => 'DJabberd::Stanza::StreamFeatures'
);

## @method
# @brief
# @param
# @return
sub new
{
	my ( $class, %opts ) = @_;

	my $ip    = delete $opts{ip};
	my $endpt = delete $opts{endpoint};
	my $queue = delete $opts{queue} or croak "no queue";
	die "unknown options" if %opts;

	croak "No 'ip' or 'endpoint'\n" unless $ip || $endpt;
	$endpt ||= DJabberd::IPEndpoint->new( $ip, 5222 );

	#create a socket
	my $sock;
	socket $sock, PF_INET, SOCK_STREAM, IPPROTO_TCP;
	unless ( $sock && defined fileno($sock) )
	{
		$queue->on_connection_failed("Cannot alloc socket");
		return;
	}
	IO::Handle::blocking( $sock, 0 );
	$ip = $endpt->addr;
	connect $sock, Socket::sockaddr_in( $endpt->port, Socket::inet_aton($ip) );
	$DJabberd::Stats::counter{connect}++;

	my $self = $class->SUPER::new( $sock, $queue->vhost->server );
	$self->log->debug( "Connecting to '$ip' for domain " . $queue->domain() );
	$self->{state} = "connecting";
	$self->{queue} = $queue;
	$self->{vhost} = $queue->vhost;

	Scalar::Util::weaken( $self->{queue} );

	return $self;
}

## @method
# @brief
# @param
# @return
sub restart_stream
{
	my $self = shift;
	my $to   = $self->{queue}->domain;
	$self->SUPER::restart_stream;
	my $xml =
"<stream:stream xmlns:stream='http://etherx.jabber.org/streams' xmlns='jabber:client' to='$to' id='$self->{stream_id}' version='1.0'>";
	$self->log_outgoing_data($xml);
	$self->write($xml);
}

## @method
# @brief
# @param
# @return
sub namespace
{
	return "jabber:client";
}

## @method
# @brief
# @param
# @return
sub start_connecting
{
	my $self = shift;
	$self->watch_write(1);
}

## @method
# @brief
# @param
# @return
sub on_connected
{
	my $self = shift;
	$self->start_init_stream(
		xmlns => "jabber:client",
		to    => $self->{queue}->{domain}
	);
	$self->watch_read(1);
}

## @method
# @brief
# @param
# @return
sub event_write
{

	my $self = shift;

	if ( $self->{state} eq "connecting" )
	{
		$self->{state} = "connected";
		$self->on_connected;
	}
	else
	{
		return $self->SUPER::event_write;
	}
}

## @method
# @brief
# @param
# @return
sub on_stream_start
{
	my ( $self, $ss ) = @_;

	$self->{in_stream} = 1;
	$self->{stream_id} = $ss->id();
	$self->log->debug("We got a stream back from connection $self->{id}!");

	#my $to_host = $ss->to;
	#DJabberd::Log->get_logger->info($to_host);
	#my $vhost = $self->server->lookup_vhost($to_host);
	#return $self->close_no_vhost($to_host)
	#    unless ($vhost);
	#$self->set_vhost($vhost);

}

## @method
# @brief
# @param
# @return
sub on_stanza_received
{
	my ( $self, $node ) = @_;

	if ( $self->xmllog->is_info )
	{
		$self->log_incoming_data($node);
	}
	if ( $node->element eq "{http://etherx.jabber.org/streams}error" )
	{

		#TODO: handle this
		return 1;
	}

	my $class = $element2class{ $node->element };
	my $stanza = $class->downbless( $node, $self );

	if ( $node->element eq "{http://etherx.jabber.org/streams}features" )
	{
		$self->log->debug("Got feature stream");
		$self->set_rcvd_features($stanza);

		if ( $self->{rcvd_features}->as_xml() =~ m/bind/ )
		{
			DJabberd::IQ->send_bind_resource($self);
		}

		#TODO: Implement old auth methods as well
		if ( not $self->{sasl}->{authed} )
		{
			DJabberd::Stanza::SASL->auth_sasl(
				$self->{queue}->user(),
				$self->{queue}->passwd(),
				$self->{queue}->resource(), $self
			);
		}
		return;
	}

	if ( $node->element =~ m/xmpp-sasl/ )
	{

		#todo: rewrite to object methods...
		DJabberd::Stanza::SASL->on_recv_from_server( $self, $node );
	}
	if ( $node->element eq "{jabber:client}iq" )
	{
		$stanza->on_recv_from_server($self);
	}
	if ( $node->element eq "{jabber:client}presence" )
	{
		$stanza->on_recv_from_server_proxycon($self);
	}
	if ( $node->element eq "{jabber:client}message" )
	{
		$stanza->on_recv_from_server($self);
	}

	$self->vhost->hook_chain_fast(
		"HandleStanza",
		[ $node, $self ],
		{
			handle => sub {
				my ( $self, $handling_class ) = @_;
				$class = $handling_class;
			},
		}
	) unless $class;
	return $self->stream_error("unsupported-stanza-type") unless $class;
}

## @method
# @brief
# @param
# @return
sub event_err
{
	my $self = shift;
	$self->{queue}->on_connection_error($self);
	return $self->SUPER::event_err;
}

## @method
# @brief
# @param
# @return
sub event_hup
{
	my $self = shift;
	return $self->event_err;
}

## @method
# @brief
# @param
# @return
sub close
{
	my $self = shift;
	return if $self->{closed};

	$self->{queue}->on_connection_error($self);
	return $self->SUPER::close;
}

1;
