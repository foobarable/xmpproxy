package xmpproxy::User;
use strict;
use warnings;

use DJabberd::Config::Config;
use DJabberd::Log;
use DJabberd::Roster;
use DJabberd::RosterItem;
use Data::Dumper;
our $logger = DJabberd::Log->get_logger();

## @method new
# @brief Constructor. Every argument is passed to the _init method. 
# @return Reference to the own object
sub new
{
	my $class = shift;
	my $self  = {};
	bless( $self, $class );
	$self->_init(@_);
	return $self;
}

## @method _init 
# @brief Initialisation method. Checks data and sets several values in the object
# @param $name The name of the user. 
# @param $passwd The password the user can authenticate itself
# @param $vhost A reference to the vhost object
# @return nothing 
sub _init
{
	my $self   = shift;
	my $name   = shift;
	my $passwd = shift;
	my $vhost  = shift;
	$self->{queues}       = {};
	$self->{jid2queue}    = {};
	$self->{defaultqueue} = undef;
	$self->{pendingiq}    = {};
	if ( defined($name) && defined($passwd) && defined($vhost) )
	{
		$self->{name}   = $name;
		$self->{passwd} = $passwd;
		$self->{vhost}  = $vhost;
	}
	else
	{
		$logger->warn("Not enough data supplied to create this user");
		return 0;
	}

}

## @method add_account
# @brief Adds an account to a users. Needs a jid, a password and a resource as input.
# @param $jid The JID xmpproxy should connect to
# @param $password The password for the given JID
# @param $resource The resource xmmproxy should try to bind the bare JID to.
# @return 0 if error, 1 if success.
sub add_account
{
	my $self     = shift;
	my $jid      = shift;
	my $password = shift;
	my $resource = shift;

	if ( not defined( $self->{queues}->{$jid} ) )
	{
		$self->{queues}->{$jid} = new DJabberd::Queue::ClientOut(
			jid      => $jid,
			passwd   => $password,
			resource => $resource,
			vhost    => $self->{vhost}
		);
	}
	else
	{
		$logger->warn("Account $jid already exists");
		return 0;
	}

	if ( scalar( keys( %{ $self->{queues} } ) ) == 1 )
	{

		$self->{defaultqueue} = $self->{queues}->{ ( keys( %{ $self->{queues} } ) )[0] };
	}

	return 1;
}

## @method delete_account 
# @brief Deletes an account from a user. Not implemented yet.
# @param $jid The JID of the account that should be deleted
# @return 0 if error, 1 if sucess
sub delete_account
{
	my $self = shift;
	die "delete_account not implemented yet";

}

## @method queues
# @brief Getter method for the reference to the queues hash
# @return Reference to a hash containing all the queues for this user
sub queues
{
	my $self = shift;
	return $self->{queues};
}

## @method fetch_rosters
# @brief Loops through all accounts and sends a roster get request for them
# @return nothing
sub fetch_rosters
{
	my $self = shift;

	foreach my $client ( keys( %{ $self->{queues} } ) )
	{
		$self->{queues}->{$client}->fetch_roster();
	}

}

## @method set_vhost
# @brief Sets the vhost this user belongs to 
# @param $vh Reference to the vhost object
# @return nothing
sub set_vhost
{
	my ( $self, $vh ) = @_;

	#print(ref($self->{vhost}));
	$self->{vhost} = $vh;
}

## @method find_conns_by_jid
# @brief Searches all connections with a specific JID in their roster.
# @param $jid_string The JID that is searched in the Rosters  
# @return nothing
sub find_conns_by_jid
{
	my $self       = shift;
	my $jid_string = shift;
	my @conns      = ();

	foreach my $client ( keys( %{ $self->queues } ) )
	{
		foreach my $item ( $self->{queues}->{$client}->{roster}->items() )
		{
			my $rosterjid = $item->jid->as_string;
			if ( $jid_string eq $rosterjid )
			{
				push( @conns, $self->{queues}->{$client}->{connection} );
			}
		}
	}
	if ( scalar(@conns) == 0 )
	{
		push( @conns, $self->{defaultqueue}->{connection} );
	}

	return @conns;
}

## @method find_queues_by_jid
# @brief Searches all queues with a specific JID in their roster.
# @param $jid_string The JID that is searched in the Rosters  
# @return nothing
sub find_queues_by_jid
{
	my $self       = shift;
	my $jid_string = shift;
	my @queues     = ();

	foreach my $client ( keys( %{ $self->queues } ) )
	{
		foreach my $item ( $self->{queues}->{$client}->{roster}->items() )
		{
			my $rosterjid = $item->jid->as_string;
			if ( $jid_string eq $rosterjid )
			{
				push( @queues, $self->{queues}->{$client} );
			}
		}
	}
	if ( scalar(@queues) == 0 )
	{
		push( @queues, $self->{defaultqueue} );
	}

	return @queues;
}

## @method get_roster
# @brief Goes through all queues and aggregates their roster items into one roster that is beeing delivered by the proxy rosterstorage plugin
# @return Reference to the merged roster
sub get_roster
{
	my $self   = shift;
	my $roster = new DJabberd::Roster;

	#TODO: Howto properly reset this hash reference?
	#$self->{jid2queue} = undef;
	#delete $self->{jid2queue};

	#Add admin bot to the roster
	my $adminsubscription = DJabberd::Subscription->new();
	my $adminjid          = new DJabberd::JID( "root" . "@" . $self->{vhost}->server_name() . "/xmpproxy" );
	$adminsubscription->set_to();
	$adminsubscription->set_from();
	my $adminbot = new DJabberd::RosterItem( jid => $adminjid, name => "root", subscription => $adminsubscription );
	$roster->add($adminbot);

	foreach my $client ( keys( %{ $self->{queues} } ) )
	{

		#TODO: Merge rosters properly...
		foreach my $item ( $self->{queues}->{$client}->{roster}->items() )
		{
			$self->{jid2queue}->{ $item->jid } = $client;
			$roster->add($item);
		}
	}
	return $roster;
}

1;
