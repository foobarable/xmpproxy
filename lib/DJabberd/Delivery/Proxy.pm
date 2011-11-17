package DJabberd::Delivery::Proxy;
use strict;
use warnings;
use base 'DJabberd::Delivery';

use DJabberd::Queue::ClientOut;
use DJabberd::Log;
#use xmpproxy::UserDB;
our $logger = DJabberd::Log->get_logger;
#sub run_after { ("DJabberd::Delivery::Local") }

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    return $self;
}

sub deliver {
	my ($self, $vhost, $cb, $stanza) = @_;
	die unless $vhost == $self->{vhost}; # sanity check
	
	$logger->warn($stanza->signature);


	my $to = $stanza->to_jid
	    or return $cb->declined;

	my $from = $stanza->from_jid;

	my $out_queue = $self->get_queue_for_user($from) or
	    return $cb->declined;

	    #TODO: rewrite stanza->from_jid here

	$DJabberd::Stats::counter{deliver_proxy}++;
	$out_queue->queue_stanza($stanza, $cb);
}

sub get_queue_for_user {
    my ($self, $fromjid) = @_;
    # TODO: we need to clean this periodically, like when connections timeout or fail
    return $xmpproxy::userdb->{users}->{$fromjid}->{queues}->{$fromjid};
   #Jabberd::Queue::ServerOut->new(source => $self,
   #                                    domain => $domain,
   #                                     vhost  => $self->{vhost});
}

1;
