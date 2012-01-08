package xmpproxy::UserDB;
use strict;
use warnings;

use DJabberd::Config::Config;
use DJabberd::Log;
use xmpproxy::User;
use Data::Dumper;
our $logger = DJabberd::Log->get_logger();
our $config = DJabberd::Config::Config->get_config;

## @method new
# @brief Constructor. Parameters are forwarded to the _init
# @return
sub new
{
	my $class = shift;
	my $self  = {};
	bless( $self, $class );
	$self->_init(@_);
	return $self;
}

## @method
# @brief
# @param
# @return
sub _init
{
	my $self  = shift;
	my $vhost = shift;
	if ( defined($vhost) )
	{
		$self->{vhost} = $vhost;
	}
	else
	{
		die "Vhost required";
	}
	$self->{users}       = {};
	$self->{proxy2local} = {};
	$self->create_from_config();
}

## @method
# @brief
# @param
# @return
sub add_user
{
	my $self     = shift;
	my $user     = shift;
	my $password = shift;
	if ( not defined( $self->{users}->{$user} ) )
	{
		$self->{users}->{$user} = new xmpproxy::User( $user, $password, $self->{vhost} );

	}
	else
	{
		$logger->warn("User $user already exists");
		return 0;
	}
	return 1;
}

## @method
# @brief
# @param
# @return
sub delete_user
{
	my $self = shift;

}

## @method
# @brief
# @param
# @return
sub print_db
{
	my $self = shift;
	$logger->debug( Dumper( $self->{users} ) );

}

## @method
# @brief
# @param
# @return
sub create_from_config
{
	my $self = shift;
	foreach my $user ( keys( %{ $config->{user} } ) )
	{
		$logger->debug("Adding user $user to user database");
		$self->add_user( $user, $config->{user}->{$user}->{passwd} );
		foreach my $account ( @{ $config->{user}->{$user}->{account} } )
		{
			$self->{users}->{$user}->add_account( $account->{jid}, $account->{passwd}, $account->{resource} );
			$self->{proxy2local}->{ $account->{jid} } = $user . "@" . $self->{vhost}->server_name();
		}
	}
}

1;
