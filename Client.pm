package Client;
use strict;
use warnings;

use Net::XMPP;
use Net::XMPP::Client;

our $client = new Net::XMPP::Client();

$client->Connect(hostname=>"milk-and-cookies.net");
	
sub get_client
{
	return $client;
}

1;
