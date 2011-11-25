package DJabberd::Delivery::Proxy;
use strict;
use warnings;
use base 'DJabberd::Delivery';

use DJabberd::Queue::ClientOut;
use DJabberd::Log;
use Data::Dumper;
#use xmpproxy::UserDB;
our $logger = DJabberd::Log->get_logger;
#sub run_after { ("DJabberd::Delivery::Local") }
$Data::Dumper::Maxdepth = 2;

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    return $self;
}

sub deliver {
	my ($self, $vhost, $cb, $stanza) = @_;
	die unless $vhost == $self->{vhost}; # sanity check
	
	#$logger->warn($stanza->signature);

	my $to = $stanza->to_jid
	    or return $cb->declined;

	my $from = $stanza->from_jid;
	my $out_queue = $self->get_queue_for_user($from,$to) or
	    return $cb->declined;
	    #TODO: rewrite stanza->from_jid here
	my $newfrom = DJabberd::JID->new($out_queue->jid);
	$stanza->set_from($newfrom);	
	#print("DELIVERING: " . $stanza->as_xml . "\n");
	$DJabberd::Stats::counter{deliver_proxy}++;
	$out_queue->queue_stanza($stanza, $cb);
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
