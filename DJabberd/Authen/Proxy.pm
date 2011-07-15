package DJabberd::Authen::Proxy;
use strict;
use base 'DJabberd::Authen';

our $client=Client::get_client();

use Carp qw(croak);

sub new {
    my $class = shift;
    my $self = $class->SUPER::new;
    $self->{_users} = {};  # username -> $password
    return $self;
}

sub can_register_jids { 1 }
sub can_unregister_jids { 1 }
sub can_retrieve_cleartext { 0 }


#TODO: Implement Unregistering accounts
sub unregister_jid {
#    my ($self, $cb, %args) = @_;
#    my $user = $args{'username'};
#    if (delete $self->{_users}{$user}) {
#        $cb->deleted;
#    } else {
#        $cb->notfound;
#    }
}


#TODO: Implement Registering accounts
sub register_jid {
#    my ($self, $cb, %args) = @_;
#    my $user = $args{'username'};
#    my $pass = $args{'password'};
	
#    if (defined $self->{_users}{$user}) {
#        $cb->conflict;
#    }

#    $self->{_users}{$user} = $pass;
#    $cb->saved;
}

sub check_cleartext {
    my ($self, $cb, %args) = @_;
    my $user = $args{'username'};
    my $pass = $args{'password'};
    
    my @result = $client->AuthSend( username=>$user,
                         	password=>$pass,
                         	resource=>"xmpproxy"
   		      );
    if($result[0] eq "ok")
    {
        $cb->accept;
    }

    $cb->reject;
}


1;
