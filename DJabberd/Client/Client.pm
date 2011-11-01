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

$client->PresenceDB();
$client->RosterDB();

my $user="test";
my $jid ="test\@milk-and-cookies.net";
my $host="milk-and-cookies.net";
my $password="test";
my $resource="xmpproxy";

$logger->info("register proxy-access-accounts.");
#iterate over configured JIDs and make connections
$logger->info("connecting account " . $jid);
$logger->debug("user: " . $user . "\n");
$logger->debug("host: " . $host . "\n");
$logger->debug("resource: " . $resource . "\n");
$client->Connect(hostname=>$host);
my @result = $client->AuthSend( username=>$user,
                         	password=>$password,
                         	resource=>$resource
   		      );
	
sub get_client
{
	return $client;
}

1;
