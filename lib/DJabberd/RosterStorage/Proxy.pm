package DJabberd::RosterStorage::Proxy;
use strict;
use warnings;
use base 'DJabberd::RosterStorage';

use DJabberd::Log;
use DJabberd::RosterItem;
our $logger = DJabberd::Log->get_logger();
use Data::Dumper;

## @method
# @brief
# @param 
# @return 
sub finalize
{

	#    my $self = shift;

	#    $self->{rosters} = {};
	#    # 'user@local' => {
	#    #   'contact@remote' => { rosteritem attribs },
	#    #   ...
	#    # }

	#    return $self;
}

## @method
# @brief
# @param 
# @return 
sub blocking { 1 }

## @method
# @brief
# @param 
# @return 
sub get_roster
{

	my ( $self, $cb, $jid ) = @_;
	my $user = $jid->node();
	$xmpproxy::userdb->{users}->{$user}->fetch_rosters();

	#TODO: Wait here for rosters to arrive
	$cb->set_roster( $xmpproxy::userdb->{users}->{$user}->get_roster() );
}

## @method
# @brief
# @param 
# @return 
sub set_roster_item
{

	my ( $self, $cb, $jid, $ritem ) = @_;
	my $jidstr  = $jid->as_bare_string;
	my $rjidstr = $ritem->jid->as_bare_string;
	my $user    = $jid->node();

	# $xmpproxy::userdb->{users}->{$node}->{$rjidstr} = {
	#    jid          => $rjidstr,
	#    name         => $ritem->name,
	#    groups       => [$ritem->groups],
	#    subscription => $ritem->subscription->as_bitmask,
	#};

	$logger->error( "Set roster item: " . $jidstr . " " . $user );
	$cb->done($ritem);
}

## @method
# @brief
# @param 
# @return 
sub addupdate_roster_item
{
	my ( $self, $cb, $jid, $ritem ) = @_;

	my $jidstr  = $jid->as_bare_string;
	my $rjidstr = $ritem->jid->as_bare_string;
	my $user    = $jid->node();
	$logger->error( "Addupdate roster item: " . $jidstr . " " . $user );

	my $olditem = $self->{rosters}->{$jidstr}->{$rjidstr};

	#    my $newitem = $self->{rosters}->{$jidstr}->{$rjidstr} = {
	#        jid          => $rjidstr,
	#        name         => $ritem->name,
	#        groups       => [$ritem->groups],
	#    };

	#    if (defined $olditem) {
	#        $ritem->set_subscription(DJabberd::Subscription->from_bitmask($olditem->{subscription}));
	#        $newitem->{subscription} = $olditem->{subscription};
	#    }
	#    else {
	#        $newitem->{subscription} = $ritem->subscription->as_bitmask;
	#    }
	#
	$cb->done($ritem);
}

## @method
# @brief
# @param 
# @return 
sub delete_roster_item
{
	my ( $self, $cb, $jid, $ritem ) = @_;

	#    $logger->debug("delete roster item!");
	#
	#    my $jidstr = $jid->as_bare_string;
	#    my $rjidstr = $ritem->jid->as_bare_string;
	#
	#    delete $self->{rosters}->{$jidstr}->{$rjidstr};

	$cb->done;
}

## @method
# @brief
# @param 
# @return 
sub load_roster_item
{
	my ( $self, $jid, $contact_jid, $cb ) = @_;

	my $jidstr  = $jid->as_bare_string;
	my $cjidstr = $contact_jid->as_bare_string;

	my $user  = $xmpproxy::userdb->{users}->{ $jid->node() };
	my $queue = $user->{queues}->{$jidstr};

	#	$logger->error(Dumper($user->{jid2queue}));
	$logger->warn( "Node: ", $jidstr, "  Contact jid: ", $contact_jid, "  User: $user", "  Queue: $queue" );

	my $options;
	foreach my $item ( @{ $queue->roster()->items() } )
	{
		if ( $item->jid_as_bare_string eq $cjidstr )
		{
			$options = $item;
		}
	}

	unless ( defined $options )
	{
		$cb->set(undef);
		return;
	}

	my $subscription = DJabberd::Subscription->from_bitmask( $options->{subscription} );

	my $item = DJabberd::RosterItem->new( %$options, subscription => $subscription );

	$cb->set($item);
	return;
}

## @method
# @brief
# @param 
# @return 
sub wipe_roster
{
	my ( $self, $cb, $jid ) = @_;

	#    my $jidstr = $jid->as_bare_string;

	#    delete $self->{rosters}->{$jidstr};

	$cb->done;
}

1;
