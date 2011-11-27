package DJabberd::Config::Config;
use strict;
use warnings;
use base 'DJabberd::Plugin';

use DJabberd::Log;
our $logger = DJabberd::Log->get_logger();
use Data::Dumper;

#for parsing our config file

use XML::Simple;

our $config = &read_config;

#&print_config();

sub read_config
{
	$logger->info("Reading config file...");
	my $config = XMLin(
		$xmpproxy::conffile,
		KeyAttr => { user => 'name' },
		ForceArray => [ 'user', 'user' => 'account' ],
		ContentKey => '-content'
	);
	$logger->info("Setting node name to $config->{node}->{name}");

	#TODO: Log some statistics to info log level...
	return $config;
}

sub print_config
{
	$logger->debug( Dumper($config) );
}

sub write_config
{
	if ( open( FH, $xmpproxy::conffile ) )
	{

		print( FH XMLout(
				$config,
				KeyAttr => { user => 'name' },
				ForceArray => [ 'user', 'user' => 'account' ],
				ContentKey => '-content'
			)
		);
	}
}

sub get_config
{

	#TODO: Implement singleton here
	return $config;
}

sub get_host
{
	$config->{node}->{name};
}

1;
