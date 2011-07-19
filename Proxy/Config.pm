package Proxy::Config;
use strict;
use warnings;
use diagnostics;

use DJabberd::Log;
our $logger = DJabberd::Log->get_logger();

#for parsing our config file
use Config::IniFiles;

#the config-file hash
my %ini;
tie %ini, 'Config::IniFiles', ( -file => $Proxy::conffile );

my %accounts = ();
my $user=undef;
my $host=undef;
my $pass=undef;
my $resource=undef;

foreach my $section ( keys(%ini) )
{
	# account for accessing proxy
	if  ( ( $section eq 'access' ) )
	{
		($user,$host) = ($ini{$section}{'jid'} =~ m/(.*)@(.*)/);
		print "host " .$host;
		$pass = $ini{$section}{'passwd'};
		$resource = $ini{$section}{'resource'};
	}
	#configured jabber accounts to proxy traffic for
	if ( ( $section eq 'account' ) )
	{
		my $jid = $ini{$section}{'jid'};
		($user,$host) = ($jid) =~ m/(.*)@(.*)/;
		$accounts{$jid}{'user'} =  $user;
		$accounts{$jid}{'host'} =  $host;
		$accounts{$jid}{'passwd'} =  $ini{$section}{'passwd'};
		$accounts{$jid}{'resource'} = $ini{$section}{'resource'};
		$logger->warn("jid: ", $jid);
		$logger->info("jid: ", $Config::accounts->{$jid}{'user'});
	}
}

sub get_accounts
{
	return \%accounts;
}

sub get_host
{
	return $host;
}

1;
