package DJabberd::Delivery::Proxy;
use strict;
use warnings;
use base 'DJabberd::Delivery';

use DJabberd::Queue::ClientOut;
use DJabberd::Log;

#use xmpproxy::UserDB;
our $logger = DJabberd::Log->get_logger;

## @method run_after 
# @brief Contains the list of delivery plugins that should be run this this
sub run_after  { ("DJabberd::Delivery::Local") }

## @method run_before
# @brief Contains the list of delivery plugins that should be run before this
sub run_before { ("DJabberd::Delivery::OfflineStorage") }


## @method new 
# @brief Constructor
sub new
{
	my $class = shift;
	my $self  = $class->SUPER::new(@_);
	return $self;
}

## @method register
# @brief Registers the delivery plugin at the vhost. Also tells the vhost that this plugin implements message carbons 
# @param $vhost A reference to the vhost object
# @return none
sub register
{
	my ( $self, $vhost ) = @_;
	$vhost->add_feature("urn:xmpp:carbons:1");
	$self->SUPER::register($vhost);
}


## @method deliver
# @brief Proxies a stanza. An incoming stanza is sent to all connected clients, an outgoing stanza is also copied to all connected clients. This is done by message carbons or via setting the from attribute to log@<hostname> 
# @param $vhost A reference to the vhost object
# @param $cb A code reference to the callback object
# @param $stanza The stanza that is about to be delivered
# @return none
sub deliver
{
	my ( $self, $vhost, $cb, $stanza ) = @_;
	die unless $vhost == $self->{vhost};    # sanity check

	#$logger->warn($stanza->signature);

	my $to = $stanza->to_jid
	  or return $cb->declined;

	my $from = $stanza->from_jid;

	# check if incoming from client (not DJabberd::Client)
	if ( exists( $xmpproxy::userdb->{users}->{ $from->node() }->{jid2queue}->{ $to->as_bare_string() } ) )
	{
		my $out_queue = $self->get_queue_for_user( $from, $to ) or return $cb->declined;

		my $clone = $stanza->clone();
		my @conns = $vhost->find_conns_of_bare($from);
		foreach my $c (@conns)
		{

			#Don't deliver the stanza to the client that sent it
			if ( not $from->eq( $c->bound_jid() ) )
			{
				my $mirrorfrom = DJabberd::JID->new( $from->as_bare_string() );
				my $mirrorto   = DJabberd::JID->new($from);
				#TODO: What about clients that don't support message carboning?
				if ( $c->carbon() )
				{
					$clone->set_from($mirrorfrom);
					$clone->set_to($mirrorto);
					my $sent =
					  DJabberd::XMLElement->new( "urn:xmpp:carbons:1", "sent", { '{}xmlns' => "urn:xmpp:carbons:1" },
						[] );
					my $forward = DJabberd::XMLElement->new(
						"urn:xmpp:forward:0", "forwarded",
						{ '{}xmlns' => "urn:xmpp:forward:0" },
						[ $sent, $stanza ]
					);
					$clone->set_raw( $forward->as_xml );
					$c->send_stanza($clone);
				}
				else
				{

				}
			}
		}

		my $newfrom = DJabberd::JID->new( $out_queue->jid );
		$stanza->set_from($newfrom);
		$DJabberd::Stats::counter{deliver_proxy}++;
		$out_queue->queue_stanza( $stanza, $cb );
		return;

		#$cb->delivered;
	}
	$cb->declined;
}

## @method get_queue_for_user
# @brief Returns a DJabberd::Queue object for a given from-to tupel
# @param $from The JID of the local xmpproxy user. 
# @param $to The JID of the account the message should be proxied to 
# @return The queue 
sub get_queue_for_user
{
	my ( $self, $from, $to ) = @_;
	my $frombare = $from->node();
	my $tobare   = $to->as_bare_string();

	# TODO: we need to clean this periodically, like when connections timeout or fail
	my $queue = $xmpproxy::userdb->{users}->{$frombare}->{jid2queue}->{$tobare};

	return $xmpproxy::userdb->{users}->{$frombare}->{queues}->{$queue};
}

1;
