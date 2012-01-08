package DJabberd::Queue::ClientOut;
use strict;
use warnings;

use base 'DJabberd::Queue';
use DJabberd::Queue qw(NO_CONN RESOLVING);
use fields ( 'jid', 'passwd', 'resource', 'user', 'domain', 'del_source', 'roster', 'sentiqs', 'receivediqs' );

use DJabberd::Connection::ClientOut;

use DJabberd::Log;

our $logger = DJabberd::Log->get_logger;

## @method
# @brief
# @param
# @return
sub new
{
	my ( $class, %opts ) = @_;

	my $jid    = delete $opts{jid}    or Carp::confess "JID required";
	my $passwd = delete $opts{passwd} or Carp::confess "Password required";
	my $resource = delete $opts{resource};
	my $self     = fields::new($class);

	#TODO: Migrate this to DJabberd::JID
	$self->{jid}    = $jid;
	$self->{passwd} = $passwd;
	( $self->{user}, $self->{domain} ) = ( split( /@/, $self->{jid} ) )[ 0 .. 1 ];

	defined($resource) ? $self->{resource} = $resource : $self->{resource} = "xmppproxy";
	$self->{roster}      = DJabberd::Roster->new;
	$self->{sentiqs}     = {};
	$self->{receivediqs} = {};
	$self->SUPER::new(%opts);
	$self->start_connecting;
	return $self;
}

## @method
# @brief
# @param
# @return
sub fetch_roster
{
	my $self = shift;
	if ( not $self->{state} == NO_CONN )
	{
		DJabberd::IQ->send_request_roster($self);
	}
}

## @method
# @brief
# @param
# @return
sub give_up_connecting
{
	my $self = shift;
	$logger->error("Connection error while connecting to $self->{domain}, giving up");
}

## @method
# @brief
# @param
# @return
sub roster
{
	my $self = shift;
	return $self->{roster};
}

## @method
# @brief
# @param
# @return
sub jid
{
	my $self = shift;
	return $self->{jid};
}

## @method
# @brief
# @param
# @return
sub user
{
	my $self = shift;
	return $self->{user};
}

## @method
# @brief
# @param
# @return
sub passwd
{
	my $self = shift;
	return $self->{passwd};
}

## @method
# @brief
# @param
# @return
sub resource
{
	my $self = shift;
	return $self->{resource};
}

## @method
# @brief
# @param
# @return
sub domain
{
	my $self = shift;
	return $self->{domain};
}

## @method
# @brief
# @param
# @return
sub queue_stanza
{
	my $self = shift;

	# Passthrough, maybe we should warn and depricate?
	return $self->SUPER::enqueue(@_);
}

## @method
# @brief
# @param
# @return
sub start_connecting
{
	my $self = shift;
	$logger->debug("Starting connection to '$self->{jid}'");
	die unless $self->{state} == NO_CONN;

	# TODO: moratorium/exponential backoff on attempting to deliver to
	# something that's recently failed to connect.  instead, immediately
	# call ->failed_to_connect without even trying.

	$self->{state} = RESOLVING;

	# async DNS lookup
	DJabberd::DNS->srv(
		service  => "_xmpp-client._tcp",
		domain   => $self->{domain},
		port     => 5222,
		callback => sub {
			$self->endpoints(@_);
			$logger->debug("Resolver callback for '$self->{domain}': [@_]");
			$self->{state} = NO_CONN;
			$self->SUPER::start_connecting;
		}
	);
}

## @method
# @brief
# @param
# @return
sub new_connection
{
	my $self = shift;
	my %opts = @_;

	return DJabberd::Connection::ClientOut->new(%opts);
}

1;
