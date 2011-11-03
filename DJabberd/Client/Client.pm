package DJabberd::Client::Client;
use strict;
use warnings;
use base 'DJabberd::Plugin';

use DJabberd::Config::Config;
use Net::XMPP;
use Net::XMPP::Client;
use DJabberd::Log;
use Data::Dumper;
our $logger = DJabberd::Log->get_logger();



sub new 
{
	my $class = shift;
	my $self = {};
	bless($self, $class);
	$self->_init(@_);
	return $self;
}

sub _init 
{
	my $self = shift;
	$self->{client} = new Net::XMPP::Client();
	$self->{client}->PresenceDB();
	$self->{client}->RosterDB();
	$self->{roster} = new DJabberd::Roster; 
	my $jid = shift;
	my $passwd = shift;
	if(defined($jid) && defined($passwd))
	{
		$self->{jid} = $jid;
		$self->{passwd} = $passwd;
		($self->{user},$self->{host}) = split(/@/,$self->{jid});
	}
	else
	{
		$logger->warn("Not enough data supplied to connect this client\n");
		return;
	}
	my $resource = shift;
	defined($resource) ? $self->{resource} = $resource : $self->{resource} = "xmppproxy";

	$logger->info("Register proxy-access-accounts.");
	$logger->info("Trying to connect account " . $self->{jid} . "/" . $self->{resource});

	eval 
	{ 
		$self->{client}->Connect(hostname=>$self->{host}); 
	};
	if ($@)
	{
		$logger->warn("Could not connect to $self->{host}");
		return 0;
	}

	my @result = ();	
	eval 
	{
		@result = $self->{client}->AuthSend( username=>$self->{user},
					password=>$self->{passwd},
					resource=>$self->{resource});


	};
	if ($@)
	{
		$logger->warn("Could not authenticate $self->{jid}. Probably no connection possible?"); 
		return 0;
	}
	
	if ($result[0] eq "error")
	{

		$logger->warn("Could not authenticate $self->{jid}: $result[1]");
	}
	elsif($result[0] eq "ok")
	{
		$logger->info("Connected account $self->{jid}");
	}
	
	#Sending presence to tell world that we are logged in
	#TODO: Load old presence..
	$self->{client}->PresenceSend();
#	$self->{client}->Process();
	$self->fetch_roster();

}

sub fetch_roster
{
	my $self = shift;
	$logger->debug("Fetching roster for $self->{jid}");
	$self->{client}->RosterRequest();

	
	#Getting Roster to tell server to send presence info
	$self->{client}->RosterGet();
#	$self->{client}->Process();  
	$logger->debug("Got roster for $self->{jid}");	


	my @jids  = $self->{client}->RosterDBJIDs();

	foreach my $jid (@jids) 
	{
	    #TODO fix subscriptiion
	    my $subscription = DJabberd::Subscription->from_bitmask(12);
	    my $item = {};
	    $item->{jid} = $jid->GetJID();
	    $item->{name} = "";
	    $item->{groups} = [];
	    $item->{remove} = "";
	    $item->{subscription} = 12;
	    $self->{roster}->add(DJabberd::RosterItem->new(%$item, subscription => $subscription));
	}

	#$logger->debug("  ... got groups, calling set_roster..");
}

	
sub get_client
{
	my $self = shift;
	return $self->{obj};
}

1;
