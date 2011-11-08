package DJabberd::Connection::ClientOut;
use strict;
use base 'DJabberd::Connection';
use fields (
            'state',
            'queue',  # our DJabberd::Queue::ClientOut
            );

use IO::Handle;
use Socket qw(PF_INET IPPROTO_TCP SOCK_STREAM);
use DJabberd::IQ;
use Carp qw(croak);
use Authen::SASL;
use vars qw( %XMLNS);


##############################################################################
# Define the namespaces in an easy/constant manner.
#-----------------------------------------------------------------------------
# 1.0
#-----------------------------------------------------------------------------
$XMLNS{'xmppstreams'}   = "urn:ietf:params:xml:ns:xmpp-streams";
$XMLNS{'xmpp-bind'}     = "urn:ietf:params:xml:ns:xmpp-bind";
$XMLNS{'xmpp-sasl'}     = "urn:ietf:params:xml:ns:xmpp-sasl";
$XMLNS{'xmpp-session'}  = "urn:ietf:params:xml:ns:xmpp-session";
$XMLNS{'xmpp-tls'}      = "urn:ietf:params:xml:ns:xmpp-tls";
##############################################################################



sub new {
    my ($class, %opts) = @_;

    my $ip    = delete $opts{ip};
    my $endpt = delete $opts{endpoint};
    my $queue = delete $opts{queue} or croak "no queue";
    die "unknown options" if %opts;

    croak "No 'ip' or 'endpoint'\n" unless $ip || $endpt;
    $endpt ||= DJabberd::IPEndpoint->new($ip, 5222);

    #create a socket
    my $sock;
    socket $sock, PF_INET, SOCK_STREAM, IPPROTO_TCP;
    unless ($sock && defined fileno($sock)) {
        $queue->on_connection_failed("Cannot alloc socket");
        return;
    }
    IO::Handle::blocking($sock, 0);
    $ip = $endpt->addr;
    connect $sock, Socket::sockaddr_in($endpt->port, Socket::inet_aton($ip));
    $DJabberd::Stats::counter{connect}++;

    my $self = $class->SUPER::new($sock, $queue->vhost->server);
    $self->log->debug("Connecting to '$ip' for '$queue->{domain}'");
    $self->{state}     = "connecting";
    $self->{queue}     = $queue;
    $self->{vhost}     = $queue->vhost;

    Scalar::Util::weaken($self->{queue});

    return $self;
}

sub namespace {
    return "jabber:client";
}

sub start_connecting {
    my $self = shift;
    $self->watch_write(1);
}

sub on_connected {
    my $self = shift;
    print("Fooo");
    $self->start_init_stream(xmlns => "jabber:client",
                             to    => $self->{queue}->{domain});
    $self->watch_read(1);
}

sub auth_send
{
	my $self =  shift;
	$self->auth_sasl( username => "test",password => "test", resource => "xmpproxy");
#	my $xml = "<iq type='get'><query xmlns='jabber:iq:auth'><username>test</username></query></iq>"; 
#	$self->log->debug($xml);
#	$self->write($xml);


#	$xml = "<iq type='set' id='822399'><query xmlns='jabber:iq:auth'><username>test</username><resource>xmpproxy</resource><password>test</password></query></iq>"; 
#	$self->log->debug($xml);
#	$self->write($xml);
}


###############################################################################
#
# SASLClient - This is a helper function to perform all of the required steps
#              for doing SASL with the server.
#
###############################################################################
sub SASLClient
{
	my $self = shift;
	my $username = shift;
	my $password = shift;

	#my $mechanisms = $self->GetStreamFeature("xmpp-sasl");
	#return unless defined($mechanisms);

	my $mechanism = "PLAIN";

	#my $sasl = new Authen::SASL(mechanism=>join(" ",@{$mechanisms}),
	my $sasl = new Authen::SASL(mechanism=>$mechanism,
                                callback=>{ user => $username,
                                            pass => $password
                                          }
                               );
       
	$self->{sasl}->{client} = $sasl->client_new();
	$self->{sasl}->{username} = $username;
	$self->{sasl}->{password} = $password;
	$self->{sasl}->{authed} = 0;
	$self->{sasl}->{done} = 0;

	$self->SASLSendAuth();
}


sub auth_sasl
{
	my $self = shift;
	my %args;
	while($#_ >= 0) { $args{ lc pop(@_) } = pop(@_); }
	   
	$self->log->debug("AuthSASL: shiney new auth");

	$self->log->error("AuthSASL requires a username arguement")
	    unless exists($args{username});
	$self->log->error("AuthSASL requires a password arguement")
	    unless exists($args{password});

	$args{resource} = "" unless exists($args{resource});

	#-------------------------------------------------------------------------
	# Create the SASLClient on our end
	#-------------------------------------------------------------------------
	#get session id here..
	my $sid = $self->{stream_id};
	my $status =
	    $self->SASLClient($sid,$args{username},$args{password});

	$args{timeout} = "120" unless exists($args{timeout});

	#-------------------------------------------------------------------------
	# While we haven't timed out, keep waiting for the SASLClient to finish
	#-------------------------------------------------------------------------
	#my $endTime = time + $args{timeout};
	#while(!$self->SASLClientDone($sid) && ($endTime >= time))
	#{
		#    $self->log->debug("AuthSASL: haven't authed yet... let's wait.");
	    #return unless (defined($self->Process(1)));
	    #ToDO: remote it, its ugly
	    #    sleep 5;
	sleep 1;
	    #&{$self->{CB}->{update}}() if exists($self->{CB}->{update});
	    #}

	#-------------------------------------------------------------------------
	# The loop finished... but was it done?
	#-------------------------------------------------------------------------
	if (!$self->SASLClientDone($sid))
	{
	    $self->log->debug("AuthSASL: timed out...");
	    return( "system","SASL timed out authenticating");
	}

	#-------------------------------------------------------------------------
	# Ok, it was done... but did we auth?
	#-------------------------------------------------------------------------
	if (!$self->SASLClientAuthed($sid))
	{
	    $self->log->debug("AuthSASL: Authentication failed.");
	    return ( "error", $self->SASLClientError($sid));
	}
#
#    #-------------------------------------------------------------------------
#    # Phew... Restart the <stream:stream> per XMPP
#    #-------------------------------------------------------------------------
#    $self->{DEBUG}->Log1("AuthSASL: We authed!");
#    $self->{SESSION} = $self->{STREAM}->OpenStream($sid);
#    $sid = $self->{SESSION}->{id};
#
#    $self->{DEBUG}->Log1("AuthSASL: We got a new session. sid($sid)");
#
#    #-------------------------------------------------------------------------
#    # Look in the new set of <stream:feature/>s and see if xmpp-bind was
#    # offered.
#    #-------------------------------------------------------------------------
#    my $bind = $self->{STREAM}->GetStreamFeature($sid,"xmpp-bind");
#    if ($bind)
#    {
#        $self->{DEBUG}->Log1("AuthSASL: Binding to resource");
#        $self->BindResource($args{resource});
#    }
#
#    #-------------------------------------------------------------------------
#    # Look in the new set of <stream:feature/>s and see if xmpp-session was
#    # offered.
#    #-------------------------------------------------------------------------
#    my $session = $self->{STREAM}->GetStreamFeature($sid,"xmpp-session");
#    if ($session)
#    {
#        $self->{DEBUG}->Log1("AuthSASL: Starting session");
#        $self->StartSession();
#    }
#
#    return ("ok","");
}




##############################################################################
#
# SASLClientDone - return 1 if the SASL process is finished
#
##############################################################################
sub SASLClientDone
{
    my $self = shift;

    return $self->{sasl}->{done};
}



##############################################################################
#
# SASLSendAuth - send an <auth/> in the SASL namespace
#
##############################################################################
sub SASLSendAuth
{
	my $self = shift;
	my $xml = "<auth xmlns='".&ConstXMLNS('xmpp-sasl')."' mechanism='".$self->SASLGetClient()->mechanism()."'/>";
	$self->log->debug($xml);
	$self->write($xml);
}


##############################################################################
#
# SASLSendChallenge - Send a <challenge/> in the SASL namespace
#
##############################################################################
sub SASLSendChallenge
{
    my $self = shift;
    my $challenge = shift;

    $self->write("<challenge xmlns='".&ConstXMLNS('xmpp-sasl')."'>${challenge}</challenge>");
}


##############################################################################
#
# SASLSendFailure - Send a <failure/> tag in the SASL namespace
#
##############################################################################
sub SASLSendFailure
{
    my $self = shift;
    my $type = shift;

    $self->write("<failure xmlns='".&ConstXMLNS('xmpp-sasl')."'><${type}/></failure>");
}


###############################################################################
#
# SASLGetClient - This is a helper function to return the SASL client object.
#
###############################################################################
sub SASLGetClient
{
    my $self = shift;

    return $self->{sasl}->{client};
}



##############################################################################
#
# ConstXMLNS - Return the namespace from the constant string.
#
##############################################################################
sub ConstXMLNS
{
    my $const = shift;

    return $XMLNS{$const};
}

##############################################################################
#
# ProcessSASLStanza - process a SASL based packet.
#
##############################################################################
sub ProcessSASLStanza
{
    my $self = shift;
    my $sid = shift;
    my $node = shift;

    my $tag = &XML::Stream::XPath($node,"name()");

    if ($tag eq "challenge")
    {
        $self->SASLAnswerChallenge($node);
    }

    if ($tag eq "failure")
    {
        $self->SASLClientFailure($node);
    }

    if ($tag eq "success")
    {
        $self->SASLClientSuccess($node);
    }
}


##############################################################################
#
# SASLAnswerChallenge - when we get a <challenge/> we need to do the grunt
#                       work to return a <response/>.
#
##############################################################################
sub SASLAnswerChallenge
{
    my $self = shift;
    my $node = shift;

    my $challenge64 = &XML::Stream::XPath($node,"text()");
    my $challenge = MIME::Base64::decode_base64($challenge64);

    my $response = $self->SASLGetClient()->client_step($challenge);

    my $response64 = MIME::Base64::encode_base64($response,"");
    $self->SASLSendResponse($response64);
}







sub event_write {
    my $self = shift;

    if ($self->{state} eq "connecting") {
        $self->{state} = "connected";
        $self->on_connected;
    } else {
        return $self->SUPER::event_write;
    }
}

sub on_stream_start {
	my ($self, $ss) = @_;

	$self->{in_stream} = 1;
	$self->log->debug("We got a stream back from connection $self->{id}!\n");
	#authenticate here
	$self->auth_send;
}

sub on_stanza_received {
	my ($self, $node) = @_;

	if ($self->xmllog->is_info) {
        	$self->log_incoming_data($node);
	}


    #unless ($node->attr("{}type") eq "valid") {
    #    # FIXME: also verify other attributes
    #    warn "Not valid?\n";
    #    return;
    #}

    $self->log->debug("Connection $self->{id} established");
    $self->{queue}->on_connection_connected($self);
}

sub event_err {
    my $self = shift;
    $self->{queue}->on_connection_error($self);
    return $self->SUPER::event_err;
}


sub event_hup {
    my $self = shift;
    return $self->event_err;
}

sub close {
    my $self = shift;
    return if $self->{closed};

    $self->{queue}->on_connection_error($self);
    return $self->SUPER::close;
}

1;
