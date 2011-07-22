package DJabberd::Client::Client;
use strict;
use warnings;
use base 'DJabberd::Plugin';

use DJabberd::Config::Config;
use Net::XMPP;
use Net::XMPP::Client;
use DJabberd::Log;
our $logger = DJabberd::Log->get_logger();

our $client = new Net::XMPP::Client();
our $accounts = DJabberd::Config::Config::get_accounts();

$client->PresenceDB();
$client->RosterDB();


$logger->info("register proxy-access-accounts.");
#iterate over configured JIDs and make connections
foreach my $jid ( keys %{$accounts}) {
	$logger->info("connecting account " . $jid);
	$logger->debug("user: " . $accounts->{$jid}{'user'} . "\n");
	$logger->debug("host: " . $accounts->{$jid}{'host'} . "\n");
	$logger->debug("resource: " . $accounts->{$jid}{'resource'} . "\n");
	$client->Connect(hostname=>$accounts->{$jid}{'host'});
	my @result = $client->AuthSend( username=>$accounts->{$jid}{'user'},
                         	password=>$accounts->{$jid}{'passwd'},
                         	resource=>$accounts->{$jid}{'resource'}
   		      );
}
	
sub get_client
{
	return $client;
}

1;
