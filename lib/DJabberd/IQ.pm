package DJabberd::IQ;
use strict;
use base qw(DJabberd::Stanza);
use DJabberd::Util qw(exml);
use DJabberd::Roster;
use Digest::SHA1;
use Data::Dumper;

use DJabberd::Log;
our $logger = DJabberd::Log->get_logger();



## @method on_recv_from_client
# @brief Method getting called when an IQ is received from a client connected to xmpproxy 
# @param $conn The connection the IQ arrived on
# @return nothing
sub on_recv_from_client
{
	my ( $self, $conn ) = @_;

	my $to = $self->to_jid;
	if ( !$to || $conn->vhost->uses_jid($to) )
	{
		$self->process($conn);
		return;
	}

	$self->deliver;
}

## @method on_recv_from_server
# @brief Method getting called when an IQ is received the  
# @param $conn The connection the IQ arrived on 
# @return nothing 
sub on_recv_from_server
{
	my ( $self, $conn ) = @_;
	my $to = $self->to_jid;

	#TODO: Check if $to is handled by any of our accounts
	#if (! $to || $conn->vhost->uses_jid($to)) {
	if (1)
	{
		$self->process($conn);
		return;
	}

	#$self->deliver;
}

#Hashref that contains iq-signature to sub mapping
my $iq_handler = {
	'get-{jabber:iq:roster}query'                      => \&process_iq_getroster,
	'set-{jabber:iq:roster}query'                      => \&process_iq_setroster,
	'get-{jabber:iq:auth}query'                        => \&process_iq_getauth,
	'set-{jabber:iq:auth}query'                        => \&process_iq_setauth,
	'set-{urn:ietf:params:xml:ns:xmpp-session}session' => \&process_iq_session,
	'set-{urn:ietf:params:xml:ns:xmpp-bind}bind'       => \&process_iq_bind,
	'set-{urn:xmpp:carbons:1}enable'                   => \&process_iq_setcarbon,

	#TODO: Forward/proxy those

	'get-{http://jabber.org/protocol/disco#info}query'  => \&process_iq_disco_info_query,
	'get-{http://jabber.org/protocol/disco#items}query' => \&process_iq_disco_items_query,

	#'get-{jabber:iq:private}query ...

	'get-{jabber:iq:register}query' => \&process_iq_getregister,
	'set-{jabber:iq:register}query' => \&process_iq_setregister,
	'set-{djabberd:test}query'      => \&process_iq_set_djabberd_test,

	#client side iq handlers
	#'result-{jabber:iq:roster}query'                      => \&process_iq_setroster,
	'result-{jabber:iq:roster}query'                      => \&process_iq_resultroster,
	'result-{urn:ietf:params:xml:ns:xmpp-session}session' => \&process_iq_resultsession,
	'result-{urn:ietf:params:xml:ns:xmpp-bind}bind'       => \&process_iq_resultbind,
};

# DO NOT OVERRIDE THIS
## @method process
# @brief Runs the hookchain that calls the specific handling function 
# @param $conn The connection of the IQ that is processed 
# @return nothing 
sub process
{
	my DJabberd::IQ $self = shift;
	my $conn = shift;

	# FIXME: handle 'result'/'error' IQs from when we send IQs
	# out, like in roster pushes

	# Trillian Jabber 3.1 is stupid and sends a lot of IQs (but non-important ones)
	# without ids.  If we respond to them (also without ids, or with id='', rather),
	# then Trillian crashes.  So let's just ignore them.
	return unless defined( $self->id ) && length( $self->id );

	$conn->vhost->run_hook_chain(
		phase    => "c2s-iq",
		args     => [$self],
		fallback => sub {
			my $sig  = $self->signature;
			my $meth = $iq_handler->{$sig};
			unless ($meth)
			{
				$self->send_error( qq{<error type='cancel'>}
					  . qq{<feature-not-implemented xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>}
					  . qq{<text xmlns='urn:ietf:params:xml:ns:xmpp-stanzas' xml:lang='en'>}
					  . qq{This feature is not implemented yet in DJabberd.}
					  . qq{</text>}
					  . qq{</error>} );
				$logger->warn("Unknown IQ packet: $sig");
				return;
			}

			$DJabberd::Stats::counter{"InIQ:$sig"}++;
			$meth->( $conn, $self );
		}
	);
}

## @method signature
# @brief Aggregates the signature of the IQ. The signature consists of the type and the element of the IQ. 
# @return The signature
sub signature
{
	my $iq = shift;
	my $fc = $iq->first_element;

	# FIXME: should signature ever get called on a bogus IQ packet?
	return $iq->type . "-" . ( $fc ? $fc->element : "(BOGUS)" );
}

## @method fowrward
# @brief Forwards the IQ to a given connection. The from and to attributes should be set accordingly before calling this function
# @param $newconn The connection the IQ shall be forwarded to
# @return nothing
sub forward
{
	my DJabberd::IQ $self = shift;
	my $newconn           = shift;
	my $xml               = $self->as_xml;
	$newconn->log_outgoing_data($xml);
	$newconn->write($xml);
}

## @method send_result
# @brief Calls send reply with \"result\" as type 
# @return nothing
sub send_result
{
	my DJabberd::IQ $self = shift;
	$self->send_reply("result");
}

## @method send_error 
# @brief Replies with an error message
# @param $raw The content of the error message. The caller must send well-formed XML (but we do the wrapping element)
# @return nothing
sub send_error
{
	my DJabberd::IQ $self = shift;
	my $raw = shift || '';
	$self->send_reply( "error", $self->innards_as_xml . "\n" . $raw );
}

## @method send_result_raw
# @brief Sends a raw xml result. The caller must send well-formed XML (but we do the wrapping element)
# @param $raw The content of the message. 
# @return nothing
sub send_result_raw
{
	my DJabberd::IQ $self = shift;
	my $raw = shift;
	return $self->send_reply( "result", $raw );
}

## @method send_reply
# @brief Sends a reply to an IQ 
# @param $type The type of the IQ. Can be set, get error or cancel 
# @param $raw The raw xml of the IQ. The caller must send well-formed XML (but we do the wrapping element).
# @return nothing 
sub send_reply
{
	my DJabberd::IQ $self = shift;
	my ( $type, $raw ) = @_;

	my $conn = $self->{connection}
	  or return;

	$raw ||= "";
	my $id       = $self->id;
	my $bj       = $conn->bound_jid;
	my $from_jid = $self->to;
	my $to       = $bj ? ( " to='" . $bj->as_string_exml . "'" ) : "";
	my $from     = $from_jid ? ( " from='" . $from_jid . "'" ) : "";
	my $xml      = qq{<iq$to$from type='$type' id='$id'>$raw</iq>};
	$conn->log_outgoing_data($xml);
	$conn->write( \$xml );
}

## @method send_bind_resource
# @brief Sends a bind request on a specific connection
# @param $conn The connection the bind request is sent to.
# @return nothing 
sub send_bind_resource
{
	my DJabberd::IQ $self = shift;
	my $conn = shift;
	if ($conn)
	{
		$conn->log->info( "Binding resource " . $conn->{queue}->resource . " to " . $conn->{queue}->jid );
		my $xml =
		    "<iq type='set' id='$conn->{stream_id}'><bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'><resource>"
		  . $conn->{queue}->resource
		  . "</resource></bind></iq>";
		$conn->log_outgoing_data($xml);
		$conn->write($xml);
	}
}

## @method process_iq_resultbind
# @brief Processes the result of the bind request and tries to start a session afterwards.
# @param $conn The connection the bind result was received on
# @param $self A reference to the IQ object  
# @return nothing 
sub process_iq_resultbind
{
	my $conn = shift;
	my DJabberd::IQ $self = shift;
	$conn->log->debug("Received an iq bind response, connection now established");
	$conn->{queue}->on_connection_connected($conn);

	#TODO: Actually parse xml package
	$conn->{queue}->{jid} = $conn->{queue}->jid() . "/" . $conn->{queue}->resource();
	$conn->set_bound_jid( new DJabberd::JID( $conn->{queue}->{jid} ) );
	$self->send_iq_session($conn);
}

## @method send_iq_session
# @brief Sends an IQ to request to start a session
# @param $conn The connection the session should be started on
# @return nothing 
sub send_iq_session
{
	my DJabberd::IQ $self = shift;
	my $conn = shift;
	if ($conn)
	{
		my $xml =
		    "<iq to='"
		  . $conn->{queue}->domain()
		  . "' type='set' id='$conn->{stream_id}'> <session xmlns='urn:ietf:params:xml:ns:xmpp-session'/></iq>";
		$conn->log->info( "Requesting session for " . $conn->{queue}->jid() );
		$conn->log_outgoing_data($xml);
		$conn->write($xml);
	}
}

## @method process_iq_resultsession
# @brief Processes the result of the session request and sends an initial presence afterwards.  
# @param $conn The connection the session result was received on 
# @param $self A reference to the IQ object
# @return nothing
sub process_iq_resultsession
{
	my $conn = shift;
	my DJabberd::IQ $self = shift;
	$conn->log->debug( "Session established for " . $conn->{queue}->jid() );
	$conn->{queue}->fetch_roster();
	DJabberd::Presence->send_initial_presence( $conn, "Hello world" );

}

## @method send_request_roster 
# @brief Sends an IQ to request a roster on a specific connection
# @param $queue A queue the roster request will be sent out
# @return nothing
sub send_request_roster
{
	my DJabberd::IQ $self = shift;
	my $queue             = shift;
	my $conn              = $queue->{connection};
	if ($conn)
	{
		$conn->log->info( "Requesting roster for " . $conn->{queue}->jid() );

		my $xml = "<iq type='get' id='rosterplz'><query xmlns='jabber:iq:roster'/></iq>";
		$conn->log_outgoing_data($xml);
		$conn->write($xml);
	}
}

## @method process_iq_resultroster
# @brief Processes the received roster and stores it in the userdatabase for this account. Later on all the stored rosters are merged when a client requests a roster.
# @param $conn The connection the result was received on
# @param $self A reference to the IQ object
# @return 
sub process_iq_resultroster
{
	my $conn = shift;
	my DJabberd::IQ $self = shift;
	$conn->log->info( "Got roster for " . $conn->{queue}->jid() );
	my $query = $self->first_child();
	foreach my $resultitem ( $query->children() )
	{
		my $subscription;
		if ( $resultitem->attrs()->{'{}subscription'} eq "both" )
		{
			$subscription = DJabberd::Subscription->new();
			$subscription->set_to();
			$subscription->set_from();
		}
		else
		{
			$subscription = DJabberd::Subscription->new_from_name( $resultitem->attrs()->{'{}subscription'} );
		}
		my $name   = $resultitem->attrs()->{'{}name'};
		my $groups = $resultitem->attrs()->{'{}groups'};
		my $jid    = $resultitem->attrs()->{'{}jid'};
		$conn->{queue}->{roster}->add(
			DJabberd::RosterItem->new( jid => $jid, name => $name, groups => $groups, subscription => $subscription ) );
	}

}

## @method process_iq_setcarbon
# @brief Sets the carbon flag for a connection if received 
# @param $conn The connection the carbon flag is set
# @param $iq Reference to the refering IQ, used to send a result
# @return 
sub process_iq_setcarbon
{
	my ( $conn, $iq ) = @_;
	$iq->send_result();
	$conn->set_carbon(1);
}

##########

## @method process_iq_disco_info_query
# @brief Processes disco info queries
# @param $conn The connection the carbon flag is set
# @param $iq Reference to the refering IQ, used to send a result
# @return nothing
sub process_iq_disco_info_query
{
	my ( $conn, $iq ) = @_;

	# Trillian, again, is fucking stupid and crashes on just
	# about anything its homemade XML parser doesn't like.
	# so ignore it when it asks for this, just never giving
	# it a reply.
	if ( $conn->vhost->quirksmode && $iq->id =~ /^trill_/ )
	{
		return;
	}

	# TODO: these can be sent back to another server I believe -- sky

	# TODO: Here we need to figure out what identities we have and
	# capabilities we have
	my $xml;
	$xml = qq{<query xmlns='http://jabber.org/protocol/disco#info'>};
	$xml .= qq{<identity category='server' type='im' name='djabberd'/>};

	foreach my $cap ( 'http://jabber.org/protocol/disco#info', $conn->vhost->features )
	{
		$xml .= "<feature var='$cap'/>";
	}
	$xml .= qq{</query>};

	$iq->send_reply( 'result', $xml );
}

## @method process_iq_disco_items_query
# @brief Processes disco items queries
# @param $conn The connection the iq arrived on
# @param $iq Reference to the refering IQ, used to send a result
# @return nothing
sub process_iq_disco_items_query
{
	my ( $conn, $iq ) = @_;

	my $vhost = $conn->vhost;

	my $items = $vhost ? $vhost->child_services : {};

	my $xml =
	    qq{<query xmlns='http://jabber.org/protocol/disco#items'>}
	  . join( '', map( { "<item jid='" . exml($_) . "' name='" . exml( $items->{$_} ) . "' />" } keys %$items ) )
	  . qq{</query>};

	$iq->send_reply( 'result', $xml );
}

## @method process_iq_get_roster
# @brief Processes a "roster get" request and runs the "RosterGet" event that DJabberd::Rosterstorage plugins can handle
# @param $conn The connection the iq arrived on
# @param $iq Reference to the refering IQ, used to send a result
# @return nothing
sub process_iq_getroster
{
	my ( $conn, $iq ) = @_;

	my $send_roster = sub {
		my $roster = shift;
		$logger->info("Sending roster to conn $conn->{id}");
		$iq->send_result_raw( $roster->as_xml );

		# JIDs who want to subscribe to us, since we were offline
		foreach my $jid (
			map  { $_->jid }
			grep { $_->subscription->pending_in } $roster->items
		  )
		{
			my $subpkt = DJabberd::Presence->make_subscribe(
				to   => $conn->bound_jid,
				from => $jid
			);

			# already in roster as pendin, we've already processed it,
			# so just deliver it (or queue it) so user can reply with
			# subscribed/unsubscribed:
			$conn->note_pend_in_subscription($subpkt);
		}
	};

	# need to be authenticated to request a roster.
	my $bj = $conn->bound_jid;
	unless ($bj)
	{
		$iq->send_error( qq{<error type='auth'>}
			  . qq{<not-authorized xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>}
			  . qq{<text xmlns='urn:ietf:params:xml:ns:xmpp-stanzas' xml:lang='en'>}
			  . qq{You need to be authenticated before requesting a roster.}
			  . qq{</text>}
			  . qq{</error>} );
		return;
	}

	# {=getting-roster-on-login}
	$conn->set_requested_roster(1);

	$conn->vhost->get_roster(
		$bj,
		on_success => $send_roster,
		on_fail    => sub {
			$send_roster->( DJabberd::Roster->new );
		}
	);

	return 1;
}

## @method process_iq_set_roster
# @brief Processes a "roster set" request. This request is forwarded to the actual xmpp server and caches the changes until the request is confirmed by the actual xmpp server. Then the client is informed that the changes to the roster were committed.
# @param $conn The connection the iq arrived on
# @param $iq Reference to the refering IQ, used to send a result
# @return nothing
sub process_iq_setroster
{
	my ( $conn, $iq ) = @_;

	#$conn->log->error($iq->as_xml());

	my $item = $iq->query->first_element;
	unless ( $item && $item->element eq "{jabber:iq:roster}item" )
	{
		$iq->send_error(    # TODO make this error proper
			qq{<error type='error-type'>}
			  . qq{<not-authorized xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>}
			  . qq{<text xmlns='urn:ietf:params:xml:ns:xmpp-stanzas' xml:lang='langcode'>}
			  . qq{You need to be authenticated before requesting a roster.}
			  . qq{</text>}
			  . qq{</error>}
		);
		return;
	}

	# {=xmpp-ip-7.6-must-ignore-subscription-values}
	my $subattr = $item->attr('{}subscription') || "";
	my $removing = $subattr eq "remove" ? 1 : 0;

	my $jid = $item->attr("{}jid")
	  or return $iq->send_error(    # TODO Yeah, this one too
		qq{<error type='error-type'>}
		  . qq{<not-authorized xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>}
		  . qq{<text xmlns='urn:ietf:params:xml:ns:xmpp-stanzas' xml:lang='langcode'>}
		  . qq{You need to be authenticated before requesting a roster.}
		  . qq{</text>}
		  . qq{</error>}
	  );

	my $name = $item->attr("{}name");

	# find list of group names to add/update.  can ignore
	# if we're just removing.
	my @groups;    # scalars of names
	unless ($removing)
	{
		foreach my $ele ( $item->children_elements )
		{
			next unless $ele->element eq "{jabber:iq:roster}group";
			push @groups, $ele->first_child;
		}
	}
	my $bj = $conn->bound_jid;
	unless ($bj)
	{
		$iq->send_error( qq{<error type='auth'>}
			  . qq{<not-authorized xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>}
			  . qq{<text xmlns='urn:ietf:params:xml:ns:xmpp-stanzas' xml:lang='en'>}
			  . qq{You need to be authenticated before requesting a roster.}
			  . qq{</text>}
			  . qq{</error>} );
		return;
	}

	
	my $ritem = DJabberd::RosterItem->new(
		jid    => $jid,
		name   => $name,
		remove => $removing,
		groups => \@groups,
	);

	my $id = $iq->id();

	#searches in which connections roster the item is we want to edit/add
	#if added, the default queue is being used
	my @queues = $xmpproxy::userdb->{users}->{ $bj->node() }->find_queues_by_jid($jid);

	my $is_outgoing = $conn->vhost->handles_jid($bj);
	my $is_incoming = !$is_outgoing;
	$conn->log->error("Bound JID: $bj | IS_OUTGOING: $is_outgoing");
	$conn->log->error( scalar(@queues) );

	foreach my $queue (@queues)
	{
		$queue->{receivediqs}->{$id} = 1;
		if ( exists( $queue->{sentiqs}->{$id} ) )
		{

			#	delete($queue->{sentiqs}->{$id});
		}
		if ( $is_outgoing && exists( $queue->{receivediqs}->{$id} ) )
		{
			$conn->log->error("Forwarding!");
			$queue->{sentiqs}->{$id} = $iq->from->as_string;
			$xmpproxy::userdb->{users}->{ $bj->node() }->{pendingiqs}->{$id} = $iq->from->as_string;
			$iq->set_from( new DJabberd::JID( $xmpproxy::userdb->{users}->{ $bj->node() }->{defaultqueue}->jid ) );
			$iq->forward( $queue->{connection} );
			$queue->{receivediqs}->{$id} = 1;
			return;
		}
	}
	my $to = $iq->to_jid;
	if ( $is_incoming && $to )
	{
		my $newto = DJabberd::JID->new( $xmpproxy::userdb->{proxy2local}->{ $to->as_bare_string } );
		$conn->log->error( Dumper( $xmpproxy::userdb->{proxy2local} ) );
		my @conns = $conn->vhost->find_conns_of_bare($newto);
		$logger->error( "CONN: ", $conn, ref($conn) );

		# TODO if ($removing), send unsubscribe/unsubscribed presence
		# stanzas.  See RFC3921 8.6
		# {=add-item-to-roster}
		my $phase = $removing ? "RosterRemoveItem" : "RosterAddUpdateItem";
		$conn->vhost->run_hook_chain(
			phase   => $phase,
			args    => [ $conn->bound_jid, $ritem ],
			methods => {
				done => sub {
					my ( $self, $ritem_final ) = @_;

					# the RosterRemoveItem isn't required to return the final item
					$ritem_final = $ritem if $removing;

					$iq->send_result;
					$conn->vhost->roster_push( $conn->bound_jid, $ritem_final );

					# TODO: section 8.6: must send a
					# bunch of presence
					# unsubscribe/unsubscribed messages
				},
				error => sub {    # TODO What sort of error stat is being hit here?
					$iq->send_error;
				},
			},
			fallback => sub {
				if ($removing)
				{

					# NOTE: we used to send an error here, but clients get
					# out of sync and we need to let them think a delete
					# happened even if it didn't.
					$iq->send_result;
				}
				else
				{    # TODO ACK, This one as well
					$iq->send_error;
				}
			}
		);
	}

	return 1;
}

## @method process_iq_getregister
# @brief Provides In-Band registration by handling the register get command.
# @param $conn The connection the iq arrived on
# @param $iq Reference to the refering IQ, used to send a result
# @return nothing
sub process_iq_getregister
{
	my ( $conn, $iq ) = @_;

	# If the entity is not already registered and the host supports
	# In-Band Registration, the host MUST inform the entity of the
	# required registration fields. If the host does not support
	# In-Band Registration, it MUST return a <service-unavailable/>
	# error. If the host is redirecting registration requests to some
	# other medium (e.g., a website), it MAY return an <instructions/>
	# element only, as shown in the Redirection section of this
	# document.
	my $vhost = $conn->vhost;
	unless ( $vhost->allow_inband_registration )
	{

		# MUST return a <service-unavailable/>
		$iq->send_error( qq{<error type='cancel' code='503'>}
			  . qq{<service-unavailable xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>}
			  . qq{<text xmlns='urn:ietf:params:xml:ns:xmpp-stanzas' xml:lang='en'>}
			  . qq{In-Band registration is not supported by this server's configuration.}
			  . qq{</text>}
			  . qq{</error>} );
		return;
	}

	# if authenticated, give them existing login info:
	if ( my $jid = $conn->bound_jid )
	{

		my $password = 0 ? "<password></password>" : "";    # TODO
		my $username = $jid->node;
		$iq->send_result_raw(
			qq{<query xmlns='jabber:iq:register'>
                                    <registered/>
                                    <username>$username</username>
                                    $password
                                    </query>}
		);
		return;
	}

	# not authenticated, ask for their required fields
	# NOTE: we send_result_raw here, which just writes, so they don't
	# need to be an available resource (since they're not even authed
	# yet) for this to work.  that's like most things in IQ anyway.
	$iq->send_result_raw(
		qq{<query xmlns='jabber:iq:register'>
                                <instructions>
                                Choose a username and password for use with this service.
                                </instructions>
                                <username/>
                                <password/>
                                </query>}
	);
}

## @method process_iq_setregister
# @brief Provides In-Band registration by handling the register set command.
# @param $conn The connection the iq arrived on
# @param $iq Reference to the refering IQ, used to send a result
# @return nothing
sub process_iq_setregister
{
	my ( $conn, $iq ) = @_;

	my $vhost = $conn->vhost;
	unless ( $vhost->allow_inband_registration )
	{

		# MUST return a <service-unavailable/>
		$iq->send_error( qq{<error type='cancel'>}
			  . qq{<service-unavailable xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>}
			  . qq{<text xmlns='urn:ietf:params:xml:ns:xmpp-stanzas' xml:lang='en'>}
			  . qq{In-Band registration is not supported by this server\'s configuration.}
			  . qq{</text>}
			  . qq{</error>} );
		return;
	}

	my $bjid = $conn->bound_jid;

	# remove (cancel) support
	my $item = $iq->query->first_element;
	if ( $item && $item->element eq "{jabber:iq:register}remove" )
	{
		if ($bjid)
		{
			my $rosterwipe = sub {
				$vhost->run_hook_chain(
					phase   => "RosterWipe",
					args    => [$bjid],
					methods => {
						done => sub {
							$iq->send_result;
							$conn->stream_error("not-authorized");
						},
					}
				);
			};

			$vhost->run_hook_chain(
				phase   => "UnregisterJID",
				args    => [ username => $bjid->node, conn => $conn ],
				methods => {
					deleted => sub {
						$rosterwipe->();
					},
					notfound => sub {
						warn "notfound.\n";
						return $iq->send_error;
					},
					error => sub {
						return $iq->send_error;
					},
				}
			);

			$iq->send_result;
		}
		else
		{
			$iq->send_error;    # TODO: <forbidden/>
		}
		return;
	}

	my $query = $iq->query
	  or die;
	my @children = $query->children;
	my $get      = sub {
		my $lname = shift;
		foreach my $c (@children)
		{
			next unless ref $c && $c->element eq "{jabber:iq:register}$lname";
			my $text = $c->first_child;
			return undef if ref $text;
			return $text;
		}
		return undef;
	};

	my $username = $get->("username");
	my $password = $get->("password");
	return $iq->send_error unless $username =~ /^\w+$/;
	return $iq->send_error if $bjid && $bjid->node ne $username;

	# create the account
	$vhost->run_hook_chain(
		phase   => "RegisterJID",
		args    => [ username => $username, conn => $conn, password => $password ],
		methods => {
			saved => sub {
				return $iq->send_result;
			},
			conflict => sub {
				my $epass = exml($password);
				return $iq->send_error(
					qq{
                                       <query xmlns='jabber:iq:register'>
                                           <username>$username</username>
                                           <password>$epass</password>
                                           </query>
                                           <error code='409' type='cancel'>
                                           <conflict xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>
                                           </error>
                                       }
				);
			},
			error => sub {
				return $iq->send_error;
			},
		}
	);

}

## @method process_iq_getauth
# @brief Provides old authentication via jabber:iq:auth. This way is deprecated, SASL should be prefered
# @param $conn The connection the iq arrived on
# @param $iq Reference to the refering IQ, used to send a result
# @return nothing
sub process_iq_getauth
{
	my ( $conn, $iq ) = @_;

	# <iq type='get' id='gaimf46fbc1e'><query xmlns='jabber:iq:auth'><username>brad</username></query></iq>

	# force SSL by not letting them login
	if ( $conn->vhost->requires_ssl && !$conn->ssl )
	{
		$conn->stream_error( "policy-violation", "Local policy requires use of SSL before authentication." );
		return;
	}

	my $username = "";
	my $child    = $iq->query->first_element;
	if ( $child && $child->element eq "{jabber:iq:auth}username" )
	{
		$username = $child->first_child;
		die "Element in username field?" if ref $username;
	}

	# FIXME:  use nodeprep or whatever, not \w+
	$username = '' unless $username =~ /^\w+$/;

	my $type =
	  ( $conn->vhost->are_hooks("GetPassword") || $conn->vhost->are_hooks("CheckDigest") )
	  ? "<digest/>"
	  : "<password/>";

	$iq->send_result_raw("<query xmlns='jabber:iq:auth'><username>$username</username>$type<resource/></query>");
	return 1;
}

## @method process_iq_getauth
# @brief Provides old authentication via jabber:iq:auth. This way is deprecated, SASL should be prefered
# @param $conn The connection the iq arrived on
# @param $iq Reference to the refering IQ, used to send a result
# @return nothing
sub process_iq_setauth
{
	my ( $conn, $iq ) = @_;

	my $id = $iq->id;

	my $query = $iq->query
	  or die;
	my @children = $query->children;

	my $get = sub {
		my $lname = shift;
		foreach my $c (@children)
		{
			next unless ref $c && $c->element eq "{jabber:iq:auth}$lname";
			my $text = $c->first_child;
			return undef if ref $text;
			return $text;
		}
		return undef;
	};

	my $username = $get->("username");
	my $resource = $get->("resource");
	my $password = $get->("password");
	my $digest   = $get->("digest");

	# "Both the username and the resource are REQUIRED for client
	# authentication" Section 3.1 of XEP 0078
	return unless $username && $username =~ /^\w+$/;
	return unless $resource;

	my $vhost = $conn->vhost;

	my $reject = sub {
		$DJabberd::Stats::counter{'auth_failure'}++;
		$iq->send_reply( "error",
			qq{<error code='401' type='auth'><not-authorized xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/></error>} );
		return 1;
	};

	my $accept = sub {
		my $cb      = shift;
		my $authjid = shift;

		# create default JID
		unless ( defined $authjid )
		{
			my $sname = $vhost->name;
			$authjid = "$username\@$sname";
		}

		# register
		my $jid = DJabberd::JID->new("$authjid");

		unless ($jid)
		{
			$reject->();
			return;
		}

		my $regcb = DJabberd::Callback->new(
			{
				registered => sub {
					( undef, my $fulljid ) = @_;
					$conn->set_bound_jid($fulljid);
					$DJabberd::Stats::counter{'auth_success'}++;
					$iq->send_result;
				},
				error => sub {
					$iq->send_error;
				},
				_post_fire => sub {
					$conn = undef;
					$iq   = undef;
				},
			}
		);

		$vhost->register_jid( $jid, $resource, $conn, $regcb );
	};

	# XXX FIXME
	# If the client ignores your wishes get a digest or password
	# We should throw an error indicating so
	# Currently we will just return authentication denied -- artur

	if ( $vhost->are_hooks("GetPassword") )
	{
		$vhost->run_hook_chain(
			phase   => "GetPassword",
			args    => [ username => $username, conn => $conn ],
			methods => {
				set => sub {
					my ( undef, $good_password ) = @_;
					if ( $password && $password eq $good_password )
					{
						$accept->();
					}
					elsif ($digest)
					{
						my $good_dig = lc( Digest::SHA1::sha1_hex( $conn->{stream_id} . $good_password ) );
						if ( $good_dig eq $digest )
						{
							$accept->();
						}
						else
						{
							$reject->();
						}
					}
					else
					{
						$reject->();
					}
				},
			},
			fallback => $reject
		);
	}
	elsif ( $vhost->are_hooks("CheckDigest") )
	{
		$vhost->run_hook_chain(
			phase   => "CheckDigest",
			args    => [ username => $username, conn => $conn, digest => $digest, resource => $resource ],
			methods => {
				accept => $accept,
				reject => $reject,
			}
		);
	}
	else
	{
		$vhost->run_hook_chain(
			phase   => "CheckCleartext",
			args    => [ username => $username, conn => $conn, password => $password ],
			methods => {
				accept => $accept,
				reject => $reject,
			}
		);
	}

	return 1;    # signal that we've handled it
}

## @method process_iq_session
# @brief Provides xmpp sessions. Sessions have been deprecated, see appendix E of: http://xmpp.org/internet-drafts/draft-saintandre-rfc3921bis-07.html BUT, we have to advertise session support since, libpurple REQUIRES it (sigh)
# @param $conn The connection the iq arrived on
# @param $iq Reference to the refering IQ, used to send a result
# @return nothing
sub process_iq_session
{
	my ( $conn, $iq ) = @_;

	my $from = $iq->from;
	my $id   = $iq->id;

	my $xml = qq{<iq from='$from' type='result' id='$id'/>};
	$conn->xmllog->info($xml);
	$conn->write( \$xml );
}

## @method process_iq_bind
# @brief Processes a bind request that binds a resource to an already authenticated bare JID.
# @param $conn The connection the iq arrived on
# @param $iq Reference to the refering IQ, used to send a result
# @return nothing
sub process_iq_bind
{
	my ( $conn, $iq ) = @_;

# <iq type='set' id='purple88621b5d'><bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'><resource>yann</resource></bind></iq>
	my $id = $iq->id;

	
	my $query = $iq->bind
	  or die;

	my $bindns   = 'urn:ietf:params:xml:ns:xmpp-bind';
	my @children = $query->children;

	my $get = sub {
		my $lname = shift;
		foreach my $c (@children)
		{
			next unless ref $c && $c->element eq "{$bindns}$lname";
			my $text = $c->first_child;
			return undef if ref $text;
			return $text;
		}
		return undef;
	};

	my $resource = $get->("resource") || DJabberd::JID->rand_resource;

	my $vhost = $conn->vhost;

	my $reject = sub {
		my $xml = <<EOX;
<iq id='$id' type='error'>
    <error type='modify'>
        <bad-request xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>
    </error>
</iq>
EOX
		$conn->xmllog->info($xml);
		$conn->write( \$xml );
		return 1;
	};

	## rfc3920 §8.4.2.2
	my $cancel = sub {
		my $reason = shift || "no reason";
		my $xml = <<EOX;
<iq id='$id' type='error'>
     <error type='cancel'>
       <not-allowed
           xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>
     </error>
   </iq>
EOX
		$conn->log->error("Reject bind request: $reason");
		$conn->xmllog->info($xml);
		$conn->write( \$xml );
		return 1;
	};

	my $sasl = $conn->sasl
	  or return $cancel->("no sasl");

	my $authjid = $conn->sasl->authenticated_jid
	  or return $cancel->("no authenticated_jid");

	# register
	my $jid = DJabberd::JID->new($authjid);

	unless ($jid)
	{
		$reject->();
		return;
	}

	my $regcb = DJabberd::Callback->new(
		{
			registered => sub {
				( undef, my $fulljid ) = @_;
				$conn->set_bound_jid($fulljid);
				$DJabberd::Stats::counter{'auth_success'}++;
				my $xml = <<EOX;
<iq id='$id' type='result'>
    <bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'>
        <jid>$fulljid</jid>
    </bind>
</iq>
EOX
				$conn->xmllog->info($xml);
				$conn->write( \$xml );
			},
			error => sub {
				$reject->();
			},
			_post_fire => sub {
				$conn = undef;
				$iq   = undef;
			},
		}
	);

	$vhost->register_jid( $jid, $resource, $conn, $regcb );
	return 1;
}

## @method id
# @brief Getter method for the id attribute of the IQ
# @return The id of the IQ
sub id
{
	return $_[0]->attr("{}id");
}

## @method type
# @brief Getter method for the type attribute of the IQ
# @return The type of the IQ 
sub type
{
	return $_[0]->attr("{}type");
}

## @method from
# @brief Getter method for the from attribute of the IQ
# @return The from attribute of the IQ 
sub from
{
	return $_[0]->attr("{}from");
}

## @method query
# @brief Checks if there is a query element in the IQ and returns it
# @return The query element
sub query
{
	my $self  = shift;
	my $child = $self->first_element
	  or return;
	my $ele = $child->element
	  or return;
	return undef unless $child->element =~ /\}query$/;
	return $child;
}

## @method bind
# @brief Checks if there is a bind element in the IQ and returns it
# @return The bind element
sub bind
{
	my $self  = shift;
	my $child = $self->first_element
	  or return;
	my $ele = $child->element
	  or return;
	return unless $child->element =~ /\}bind$/;
	return $child;
}

## @method deliver_when_unavailable
# @brief ???
# @return  ???
sub deliver_when_unavailable
{
	my $self = shift;
	return $self->type eq "result"
	  || $self->type   eq "error";
}

## @method make_response
# @brief Creates a proper response to the IQ
# @return the response-IQ
sub make_response
{
	my ($self) = @_;

	my $response = $self->SUPER::make_response();
	$response->attrs->{"{}type"} = "result";
	return $response;
}

1;
