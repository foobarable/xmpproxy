package xmpproxy::User;
use strict;
use warnings;

use DJabberd::Config::Config;
use DJabberd::Log;
use DJabberd::Roster;
use DJabberd::RosterItem;
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
	my $name = shift;
	my $passwd = shift;
	my $vhost = shift;
	$self->{queues} = {};
	$self->{jid2queue} = {};  
	if(defined($name) && defined($passwd) && defined($vhost))
	{
		$self->{name} = $name;
		$self->{passwd} = $passwd;
		$self->{vhost} = $vhost;
	}
	else
	{
		$logger->warn("Not enough data supplied to create this user");
		return 0;
	}

}

sub add_account
{
	my $self = shift;
	my $jid = shift;
	my $password = shift;
	my $resource = shift;
	if(not defined($self->{queues}->{$jid}))
	{
		$self->{queues}->{$jid} = new DJabberd::Queue::ClientOut(jid => $jid,
									 passwd => $password,
									 resource => $resource,
								 	 vhost => $self->{vhost});
	}
	else
	{	
		$logger->warn("Account $jid already exists");
		return 0;
	}	
	
	return 1;
}

sub delete_account
{
	my $self = shift;

}

sub fetch_rosters
{
	my $self = shift;
	
	foreach my $client (keys(%{$self->{queues}}))
	{
		$self->{queues}->{$client}->fetch_roster();
	}
	
}

sub set_vhost
{
	my ($self,$vh) = @_;
	#print(ref($self->{vhost}));
	$self->{vhost}= $vh;
}

sub get_roster
{
	my $self = shift;
	my $roster = new DJabberd::Roster; 
	
	#Howto properly reset this hash reference?
	#$self->{jid2queue} = undef;
	#delete $self->{jid2queue};
	foreach my $client (keys(%{$self->{queues}}))
	{
		#TODO: Merge rosters properly...
		foreach my $item ($self->{queues}->{$client}->{roster}->items())
		{
				$self->{jid2queue}->{$item->jid} = $client;
				$roster->add($item);
		}
	}
	return $roster; 
}


1;
