package Proxy::Client;
use strict;
use warnings;

use DJabberd::Log;
use Proxy::Config;
use Net::XMPP;
use Net::XMPP::Client;
our $logger = DJabberd::Log->get_logger();

our $client = new Net::XMPP::Client();
our $accounts = Proxy::Config::get_accounts();

$client->PresenceDB();
$client->RosterDB();


#register proxy-access-account
#iterate over configured JIDs and make connections
foreach my $jid ( keys %{$accounts}) {
	print "username: " . $accounts->{$jid}{'user'} . "\n";
	print "username: " . $accounts->{$jid}{'host'} . "\n";
	print "passwd: " . $accounts->{$jid}{'passwd'} . "\n";
	print "resource: " . $accounts->{$jid}{'resource'} . "\n";
	$logger->info("connecting account ...");
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
