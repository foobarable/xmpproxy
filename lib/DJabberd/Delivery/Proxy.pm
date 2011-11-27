package DJabberd::Delivery::Proxy;
use strict;
use warnings;
use base 'DJabberd::Delivery';

use DJabberd::Queue::ClientOut;
use DJabberd::Log;
use Data::Dumper;
#use xmpproxy::UserDB;
our $logger = DJabberd::Log->get_logger;
sub run_after { ("DJabberd::Delivery::Local") }
sub run_before { ("DJabberd::Delivery::OfflineStorage") }
$Data::Dumper::Maxdepth = 2;

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    return $self;
}

sub register
{	
	my ($self, $vhost) = @_;
	$vhost->add_feature("urn:xmpp:carbons:1");
	$self->SUPER::register($vhost);
}

sub deliver {
	my ($self, $vhost, $cb, $stanza) = @_;
	die unless $vhost == $self->{vhost}; # sanity check
	
	#$logger->warn($stanza->signature);

	my $to = $stanza->to_jid
	    or return $cb->declined;

	my $from = $stanza->from_jid;
	
	#TODO: check if incoming from client (not DJabberd::Client)
	if( exists($xmpproxy::userdb->{users}->{$from->node()}->{jid2queue}->{$to->as_bare_string()}))
	{
		my $out_queue = $self->get_queue_for_user($from,$to) or return $cb->declined;


		my @conns = $vhost->find_conns_of_bare($from);
		foreach my $c (@conns)
		{
			if ($c->carbon() )
			{
				my $clone = $stanza->clone();
				my $mirrorfrom = DJabberd::JID->new($from->as_bare_string());
				my $mirrorto = DJabberd::JID->new($from);
				$clone->set_from($mirrorfrom);
				$clone->set_to($mirrorto);
				my $sent = DJabberd::XMLElement->new("urn:xmpp:carbons:1", "sent", { '{}xmlns' => "urn:xmpp:carbons:1"} , [] ); 
				my $forward = DJabberd::XMLElement->new("urn:xmpp:forward:0", "forwarded", { '{}xmlns' => "urn:xmpp:forward:0"} , [$sent,$stanza]); 
				$clone->set_raw($forward->as_xml);
				$c->log->warn($clone->as_xml);
				$c->send_stanza($clone)
			}
		}
		
		
		my $newfrom = DJabberd::JID->new($out_queue->jid);
		$stanza->set_from($newfrom);	
		$DJabberd::Stats::counter{deliver_proxy}++;
		$out_queue->queue_stanza($stanza, $cb);
		return;
		#$cb->delivered;
	}
	$cb->declined;
}

sub get_queue_for_user {
	my ($self, $from,$to) = @_;	
	my $frombare = $from->node();
	my $tobare = $to->as_bare_string();
	# TODO: we need to clean this periodically, like when connections timeout or fail
	my $queue = $xmpproxy::userdb->{users}->{$frombare}->{jid2queue}->{$tobare};
	
	return $xmpproxy::userdb->{users}->{$frombare}->{queues}->{$queue}; 
}

1;
