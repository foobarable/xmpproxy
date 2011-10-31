package DJabberd::Authen::Proxy;
use strict;
use base 'DJabberd::Authen';

use DJabberd::Log;
our $logger = DJabberd::Log->get_logger();

our $client=DJabberd::Client::Client::get_client();

use Carp qw(croak);

sub new {
    my $class = shift;
    my $self = $class->SUPER::new;
    $self->{_users} = {};  # username -> $password
    return $self;
}

sub can_register_jids { 0 }
sub can_unregister_jids { 0 }
sub can_retrieve_cleartext { 0 }


#TODO: Implement Unregistering accounts. not needed really. Only single account!
sub unregister_jid {
#    my ($self, $cb, %args) = @_;
#    my $user = $args{'username'};
#    if (delete $self->{_users}{$user}) {
#        $cb->deleted;
#    } else {
#        $cb->notfound;
#    }
}


#TODO: Implement Registering accounts. not needed really. Only single account!
sub register_jid {
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

sub check_cleartext {
    my ($self, $cb, %args) = @_;
    my $user = $args{'username'};
    my $pass = $args{'password'};
    $logger->debug("user: " . $user . "\n");
    $logger->debug("host: " . $pass . "\n");
    $logger->debug(keys(%{$self->{_users}}));    
    unless (defined $self->{_users}{$user}) {
	#the user did not exist
        return $cb->reject;
    }

    my $goodpass = $self->{_users}{$user};
    unless ($pass eq $goodpass) {
	#password was wrong
        return $cb->reject;
    }

    $cb->accept;

    #initial pass-through an writing new proxy-account to config
    #my @result = $client->AuthSend( username=>$user,
    #                     	password=>$pass,
    #                     	resource=>"xmpproxy"
   	#	      );
    #if($result[0] eq "ok")
    #{
    #    $cb->accept;
    #}
    #write config
    #...

    $cb->reject;
}


1;
