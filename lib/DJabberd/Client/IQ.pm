package DJabberd::Client::IQ;
use strict;
use base qw(DJabberd::IQ);
use DJabberd::Util qw(exml);
use DJabberd::Roster;

use DJabberd::Log;
our $logger = DJabberd::Log->get_logger();

sub on_recv_from_server {
	my ($self, $conn) = @_;

	my $to = $self->to_jid;
	if (! $to || $conn->vhost->uses_jid($to)) {
	    $self->process($conn);
	    return;
	}

	$self->deliver;
}

sub send_bind_resource
{
	my DJabberd::Client::IQ $self = shift;
	my $conn = shift;
	$conn->log->info("Binding resource " . $conn->{queue}->resource . " to " . $conn->{queue}->jid);
	my $xml = "<iq type='set' id='$conn->{stream_id}'><bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'><resource>" . $conn->{queue}->resource ."</resource></bind></iq>";
	$conn->log_outgoing_data($xml);		
	$conn->write($xml);
}

sub process_iq_bind
{
	my $conn = shift;
	my DJabberd::Client::IQ $self = shift;
	#my $conn = $self->connection;
	$conn->log->debug("Received an iq bind response, connection now established");
	$conn->{queue}->on_connection_connected($conn);
	#TODO: Actually parse xml package
	$conn->{queue}->{jid} = $conn->{queue}->jid() . "/" . $conn->{queue}->resource();
	$self->send_iq_session($conn);

}


sub send_iq_session
{
	my DJabberd::Client::IQ $self = shift;
	my $conn = shift;
	my $xml = "<iq to='" . $conn->{queue}->domain() . "' type='set' id='$conn->{stream_id}'> <session xmlns='urn:ietf:params:xml:ns:xmpp-session'/></iq>";
	$conn->log->debug("Requesting session for " . $conn->{queue}->jid());
	$conn->log_outgoing_data($xml);		
	$conn->write($xml);
}


sub process_iq_session
{
	my $conn=shift;
	my DJabberd::Client::IQ $self = shift;

	$conn->log->debug("Session established for " . $conn->{queue}->jid());
	DJabberd::Client::Presence->initial_presence($conn,"Hello world");

}

my $iq_handler = {
#    'get-{jabber:iq:roster}query' => \&process_iq_getroster,
#    'set-{jabber:iq:roster}query' => \&process_iq_setroster,
#    'get-{jabber:iq:auth}query' => \&process_iq_getauth,
#    'set-{jabber:iq:auth}query' => \&process_iq_setauth,
    'result-{urn:ietf:params:xml:ns:xmpp-session}session' => \&process_iq_session,
    'result-{urn:ietf:params:xml:ns:xmpp-bind}bind' => \&process_iq_bind,
#    'get-{http://jabber.org/protocol/disco#info}query'  => \&process_iq_disco_info_query,
#    'get-{http://jabber.org/protocol/disco#items}query' => \&process_iq_disco_items_query,
#    'get-{jabber:iq:register}query' => \&process_iq_getregister,
#    'set-{jabber:iq:register}query' => \&process_iq_setregister,
};

# DO NOT OVERRIDE THIS
sub process {
    my DJabberd::Client::IQ $self = shift;
    my $conn = shift;

    # FIXME: handle 'result'/'error' IQs from when we send IQs
    # out, like in roster pushes

    # Trillian Jabber 3.1 is stupid and sends a lot of IQs (but non-important ones)
    # without ids.  If we respond to them (also without ids, or with id='', rather),
    # then Trillian crashes.  So let's just ignore them.
    return unless defined($self->id) && length($self->id);

    $conn->vhost->run_hook_chain(phase    => "c2s-iq",
                                 args     => [ $self ],
                                 fallback => sub {
                                     my $sig = $self->signature;
                                     my $meth = $iq_handler->{$sig};
                                     unless ($meth) {
                                         $self->send_error(
                                            qq{<error type='cancel'>}.
                                            qq{<feature-not-implemented xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>}.
                                            qq{<text xmlns='urn:ietf:params:xml:ns:xmpp-stanzas' xml:lang='en'>}.
                                            qq{This feature is not implemented yet in DJabberd.}.
                                            qq{</text>}.
                                            qq{</error>}
                                         );
                                         $logger->warn("Unknown IQ packet: $sig");
                                         return;
                                     }

                                     $DJabberd::Stats::counter{"InIQ:$sig"}++;
                                     $meth->($conn, $self);
                                 });
}

sub signature {
    my $iq = shift;
    my $fc = $iq->first_element;
    # FIXME: should signature ever get called on a bogus IQ packet?
    return $iq->type . "-" . ($fc ? $fc->element : "(BOGUS)");
}

sub send_result {
    my DJabberd::IQ $self = shift;
    $self->send_reply("result");
}

sub send_error {
    my DJabberd::IQ $self = shift;
    my $raw = shift || '';
    $self->send_reply("error", $self->innards_as_xml . "\n" . $raw);
}

# caller must send well-formed XML (but we do the wrapping element)
sub send_result_raw {
    my DJabberd::IQ $self = shift;
    my $raw = shift;
    return $self->send_reply("result", $raw);
}

sub send_reply {
    my DJabberd::IQ $self = shift;
    my ($type, $raw) = @_;

    my $conn = $self->{connection}
        or return;

    $raw ||= "";
    my $id = $self->id;
    my $bj = $conn->bound_jid;
    my $from_jid = $self->to;
    my $to = $bj ? (" to='" . $bj->as_string_exml . "'") : "";
    my $from = $from_jid ? (" from='" . $from_jid . "'") : "";
    my $xml = qq{<iq$to$from type='$type' id='$id'>$raw</iq>};
    $conn->xmllog->info($xml);
    $conn->write(\$xml);
}



sub id {
    return $_[0]->attr("{}id");
}

sub type {
    return $_[0]->attr("{}type");
}

sub from {
    return $_[0]->attr("{}from");
}

sub query {
    my $self = shift;
    my $child = $self->first_element
        or return;
    my $ele = $child->element
        or return;
    return undef unless $child->element =~ /\}query$/;
    return $child;
}

sub bind {
    my $self = shift;
    my $child = $self->first_element
        or return;
    my $ele = $child->element
        or return;
    return unless $child->element =~ /\}bind$/;
    return $child;
}

sub deliver_when_unavailable {
    my $self = shift;
    return $self->type eq "result" ||
        $self->type eq "error";
}

sub make_response {
    my ($self) = @_;

    my $response = $self->SUPER::make_response();
    $response->attrs->{"{}type"} = "result";
    return $response;
}

1;
