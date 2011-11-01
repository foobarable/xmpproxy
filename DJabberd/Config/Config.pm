package DJabberd::Config::Config;
use strict;
use warnings;
use base 'DJabberd::Plugin';

use DJabberd::Log;
our $logger = DJabberd::Log->get_logger();

#for parsing our config file
use Config::Scoped;

our $config = Config::Scoped->new( file => $xmpproxy::conffile )->parse;
die "Could not read config!\n" unless ref $config;


my %accounts = ();
my $user=undef;
my $host=undef;
my $pass=undef;
my $resource=undef;

#foreach my $foo (keys(%{$config}))
#{
#	print $config->{$foo}->{accounts}{"test\@milk-and-cookies.net"}{passwd};
#} 


#foreach my $section ( keys(%ini) )
#{
#	# account for accessing proxy
#	if  ( ( $section eq 'access' ) )
#	{
#		($user,$host) = ($ini{$section}{'jid'} =~ m/(.*)@(.*)/);
#		$logger->info("hostname: ", $host);
#		$pass = $ini{$section}{'passwd'};
#		$resource = $ini{$section}{'resource'};
#	}
#	#configured jabber accounts to proxy traffic for
#	if ( ( $section eq 'account' ) )
#	{
#		my $jid = $ini{$section}{'jid'};
#		($user,$host) = ($jid) =~ m/(.*)@(.*)/;
#		$accounts{$jid}{'user'} =  $user;
#		$accounts{$jid}{'host'} =  $host;
#		$accounts{$jid}{'passwd'} =  $ini{$section}{'passwd'};
#		$accounts{$jid}{'resource'} = $ini{$section}{'resource'};
#		$logger->info("jid: ", $jid);
#	}
#}

sub get_config
{
	return $config;
}

sub get_host
{
	return "milk-and-cookies.net";
}

1;
