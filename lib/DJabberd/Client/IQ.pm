package DJabberd::Client::IQ;
use strict;
use base qw(DJabberd::IQ);
use DJabberd::Util qw(exml);
use DJabberd::Roster;
use Data::Dumper;

use DJabberd::Log;
our $logger = DJabberd::Log->get_logger();

my $iq_handler = {
#    'get-{jabber:iq:roster}query' => \&process_iq_getroster,
#    'set-{jabber:iq:roster}query' => \&process_iq_setroster,
#    'get-{jabber:iq:auth}query' => \&process_iq_getauth,
#    'set-{jabber:iq:auth}query' => \&process_iq_setauth,
	'result-{jabber:iq:roster}query' => \&process_iq_roster,
	'result-{urn:ietf:params:xml:ns:xmpp-session}session' => \&process_iq_session,
	'result-{urn:ietf:params:xml:ns:xmpp-bind}bind' => \&process_iq_bind,
#    'get-{http://jabber.org/protocol/disco#info}query'  => \&process_iq_disco_info_query,
#    'get-{http://jabber.org/protocol/disco#items}query' => \&process_iq_disco_items_query,
#    'get-{jabber:iq:register}query' => \&process_iq_getregister,
#    'set-{jabber:iq:register}query' => \&process_iq_setregister,
};

sub on_recv_from_server {
	my ($self, $conn) = @_;
	my $to = $self->to_jid;
	#TODO: Check if $to is handled by any of our accounts
	#if (! $to || $conn->vhost->uses_jid($to)) {
	if( 1 )
	{
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
	$conn->log->info("Requesting session for " . $conn->{queue}->jid());
	$conn->log_outgoing_data($xml);		
	$conn->write($xml);
}


sub process_iq_session
{
	my $conn=shift;
	my DJabberd::Client::IQ $self = shift;
	$conn->log->debug("Session established for " . $conn->{queue}->jid());
	$conn->{queue}->fetch_roster();
	DJabberd::Client::Presence->initial_presence($conn,"Hello world");

}


sub send_request_roster
{
	my DJabberd::Client::IQ $self = shift;
	my $queue = shift;
	my $conn = $queue->{connection};
	$conn->log->info("Requesting roster for " . $conn->{queue}->jid());
		
	my $xml = "<iq type='get' id='rosterplz'><query xmlns='jabber:iq:roster'/></iq>";
	$conn->log_outgoing_data($xml);		
	$conn->write($xml);
}

sub process_iq_roster
{
	my $conn=shift;
	my DJabberd::Client::IQ $self = shift;
	$conn->log->info("Got roster for " . $conn->{queue}->jid());
	my $query = $self->first_child();
	foreach my $resultitem ($query->children())
	{
		my $subscription; 
		if($resultitem->attrs()->{'{}subscription'} eq "both")
		{
			$subscription = DJabberd::Subscription->new();
			$subscription->set_to();
			$subscription->set_from();
		}
		else
		{
			$subscription =  DJabberd::Subscription->new_from_name($resultitem->attrs()->{'{}subscription'});
		}
		my $name = $resultitem->attrs()->{'{}name'};
		my $groups = $resultitem->attrs()->{'{}groups'};
		my $jid = $resultitem->attrs()->{'{}jid'};
		$conn->{queue}->{roster}->add(DJabberd::RosterItem->new(jid => $jid, name => $name, groups => $groups , subscription => $subscription));
	}

}

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





1;
