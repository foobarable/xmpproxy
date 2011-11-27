package DJabberd::Authen::Proxy;
use strict;
use base 'DJabberd::Authen';

use DJabberd::Log;
our $logger = DJabberd::Log->get_logger();

use Carp qw(croak);

sub new
{
	my $class = shift;
	my $self  = $class->SUPER::new;
	return $self;
}

sub can_register_jids      { 0 }
sub can_unregister_jids    { 0 }
sub can_retrieve_cleartext { 0 }

#TODO: Implement Unregistering accounts. not needed really. Only single account!
sub unregister_jid
{

	#    my ($self, $cb, %args) = @_;
	#    my $user = $args{'username'};
	#    if (delete $self->{_users}{$user}) {
	#        $cb->deleted;
	#    } else {
	#        $cb->notfound;
	#    }
}

#TODO: Implement Registering accounts. not needed really. Only single account!
sub register_jid
{

	#    my ($self, $cb, %args) = @_;
	#    my $user = $args{'username'};
	#    my $pass = $args{'password'};
	#
	#    if (defined $self->{_users}{$user}) {
	#        $cb->conflict;
	#    }
	#
	#    $self->{_users}{$user} = $pass;
	#    $cb->saved;
}

sub check_cleartext
{
	my ( $self, $cb, %args ) = @_;
	my $user   = $args{'username'};
	my $pass   = $args{'password'};
	my $userdb = $xmpproxy::userdb;

	#TODO: Sanitize input
	$logger->debug( "User " . $user . " tries to authenticate" );
	unless ( defined $userdb->{users}->{$user} )
	{

		#the user did not exist
		$logger->info("Authentication failed: User $user does not exist");
		return $cb->reject;
	}

	my $goodpass = $userdb->{users}->{$user}->{passwd};
	unless ( $pass eq $goodpass )
	{
		$logger->info("Authentication failed: Wrong credentials");

		#password was wrong
		return $cb->reject;
	}

	$cb->accept;
}

1;
