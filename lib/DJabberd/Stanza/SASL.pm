package DJabberd::Stanza::SASL;
use strict;
use warnings;
use base qw(DJabberd::Stanza);
use vars qw(%XMLNS);
use Authen::SASL;
use Data::Dumper;


use MIME::Base64 qw/encode_base64 decode_base64/;



#CLIENT SUBS

# Define the namespaces in an easy/constant manner.
$XMLNS{'xmppstreams'}   = "urn:ietf:params:xml:ns:xmpp-streams";
$XMLNS{'xmpp-bind'}     = "urn:ietf:params:xml:ns:xmpp-bind";
$XMLNS{'xmpp-sasl'}     = "urn:ietf:params:xml:ns:xmpp-sasl";
$XMLNS{'xmpp-session'}  = "urn:ietf:params:xml:ns:xmpp-session";
$XMLNS{'xmpp-tls'}      = "urn:ietf:params:xml:ns:xmpp-tls";


sub on_recv_from_server { die "unimplemented"; }



# SASLClient - This is a helper function to perform all of the required steps
#              for doing SASL with the server.
sub SASLClient
{
	my $conn = shift;
	my $username = shift;
	my $passwd = shift;

	#my $mechanisms = $self->GetStreamFeature("xmpp-sasl");
	#return unless defined($mechanisms);

	my $mechanism = "DIGEST-MD5";

	#my $sasl = new Authen::SASL(mechanism=>join(" ",@{$mechanisms}),
	my $sasl = new Authen::SASL(mechanism=>$mechanism,
                                callback=>{ user => $username,
                                            pass => $passwd
                                          }
                               );
       
	$conn->{sasl}->{client} = $sasl->client_new("xmpp","milk-and-cookies.net");
	$conn->{sasl}->{username} = $username;
	$conn->{sasl}->{password} = $passwd;
	$conn->{sasl}->{authed} = 0;
	$conn->{sasl}->{done} = 0;
	
	my $init = $conn->{sasl}->{client}->client_start();
	$init = $init ? encode_base64($init, '') : "=";

	&SASLSendAuth($conn,$init);
}


sub auth_sasl
{
	my $self =shift;
	my ($username, $passwd, $resource, $conn) = @_;
	
	
	

	if (ref($conn) ne "DJabberd::Connection::ClientOut")
	{
		Carp::croak "Connection needed..";
	}

	$conn->log->debug("AuthSASL: shiney new auth");

	$conn->log->error("AuthSASL requires a username arguement")
	    unless defined($username);
	$conn->log->error("AuthSASL requires a password arguement")
	    unless defined($passwd);

	$resource = "xmpproxy" unless defined($resource);

	# Create the SASLClient on our end
	my $sid = $conn->{stream_id};
	my $status = SASLClient($conn,$username,$passwd);

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

# SASLClientSuccess - handle a received <success/>
sub SASLClientSuccess
{
    my $conn = shift;
    my $node = shift;

    $conn->{sasl}->{authed} = 1;
    $conn->{sasl}->{done} = 1;
}



# SASLClientDone - return 1 if the SASL process is finished
sub SASLClientDone
{
	my $conn = shift;

	return $conn->{sasl}->{done};
}

# SASLSendAuth - send an <auth/> in the SASL namespace
sub SASLSendAuth
{
	my $conn = shift;
	my $init = shift;
	my $xml = "<auth xmlns='".&ConstXMLNS('xmpp-sasl')."' mechanism='".&SASLGetClient($conn)->mechanism()."'>$init</auth>";
	$conn->log_outgoing_data($xml);
	$conn->write($xml);
}

# SASLSendChallenge - Send a <challenge/> in the SASL namespace
sub SASLSendChallenge
{
	my $conn = shift;	
	my $challenge = shift;
	$conn->write("<challenge xmlns='".&ConstXMLNS('xmpp-sasl')."'>${challenge}</challenge>");
}


# SASLSendFailure - Send a <failure/> tag in the SASL namespace
sub SASLSendFailure
{
	my $conn = shift;
	my $type = shift;
	
	$conn->write("<failure xmlns='".&ConstXMLNS('xmpp-sasl')."'><${type}/></failure>");
}

# SASLSendResponse - Send a <response/> tag in the SASL namespace
sub SASLSendResponse
{
	my $conn = shift;
	my $response = shift;
	$response = "<response xmlns='".&ConstXMLNS('xmpp-sasl')."'>${response}</response>";
	$conn->log_outgoing_data($response);
	$conn->write($response);
}

# SASLClientFailure - handle a received <failure/>
sub SASLClientFailure
{
    my $conn = shift;
    my $node = shift;

    my $type = $node->first_child();

    $conn->{sasl}->{error} = $type;
    $conn->{sasl}->{done} = 1;
}

# SASLGetClient - This is a helper function to return the SASL client object.
sub SASLGetClient
{
    my $conn = shift;

    return $conn->{sasl}->{client};
}



# ConstXMLNS - Return the namespace from the constant string.
sub ConstXMLNS
{
	my $const = shift;
	return $XMLNS{$const};
}

# ProcessSASLStanza - process a SASL based packet.
sub ProcessSASLStanza
{
	my $self = shift;
	my $conn = shift;
	#my $sid = shift;
	my $node = shift;
	#
	my $tag = $node->element_name;

	if ($tag eq "challenge")
	{
	    &SASLAnswerChallenge($conn,$node);
	}

	if ($tag eq "failure")
	{
	    &SASLClientFailure($conn,$node);
	}

	if ($tag eq "success")
	{
		&SASLClientSuccess($conn,$node);
	}
}


# SASLAnswerChallenge - when we get a <challenge/> we need to do the grunt
#                       work to return a <response/>.
sub SASLAnswerChallenge
{
	#my $self = shift;
	my $conn = shift;
	my $node = shift;


	my $challenge64 = $node->first_child();
	my $challenge = MIME::Base64::decode_base64($challenge64);

	my $response = &SASLGetClient($conn)->client_step($challenge);

	my $response64 = MIME::Base64::encode_base64($response,"");
	&SASLSendResponse($conn,$response64);
}





























#SERVER SUBS


## TODO:
## check number of auth failures, force deconnection, bad for t time §7.3.5 policy-violation
## Provide hooks for Authen:: modules to return details about errors:
## - credentials-expired
## - account-disabled
## - invalid-authzid
## - temporary-auth-failure
## these hooks should probably additions to parameters taken by GetPassword, CheckClearText
## right now all these errors results in not-authorized being returned

sub on_recv_from_client {
    my $self = shift;

    return $self->handle_abort(@_)
        if $self->element_name eq 'abort';

    return $self->handle_response(@_)
        if $self->element_name eq 'response';

    return $self->handle_auth(@_)
        if $self->element_name eq 'auth';
}

## supports §7.3.4, §7.4.1
## handles: <abort xmlns='urn:ietf:params:xml:ns:xmpp-sasl'/>
sub handle_abort {
    my ($self, $conn) = @_;

    $self->send_failure("aborted" => $conn);
    return;
}

sub handle_response {
    my $self = shift;
    my ($conn) = @_;

    my $sasl = $conn->sasl
        or return $self->send_failure("malformed-request" => $conn);

    if (my $error = $sasl->error) {
        return $self->send_failure("not-authorized" => $conn);
    }
    if (! $sasl->need_step) {
        $conn->log->info("sasl negotiation unexpected end");
        return $self->send_failure("malformed-request" => $conn);
    }

    my $response = $self->first_child;
    $response = $self->decode($response);
    $conn->log->info("Got the response $response");

    $sasl->server_step(
        $response => sub { $self->send_reply($conn->{sasl}, shift() => $conn) },
    );
}

sub handle_auth {
    my ($self, $conn) = @_;

    my $fallback = sub {
        $self->send_failure("invalid-mechanism" => $conn);
    };

    my $vhost = $conn->vhost
        or die "There is no vhost";

    my $saslmgr;
    $vhost->run_hook_chain( phase => "GetSASLManager",
                            args  => [ conn => $conn ],
                            methods => {
                                get => sub {
                                     (undef, $saslmgr) = @_;
                                },
                            },
                            fallback => $fallback,
    );
    die "no SASL" unless $saslmgr; 

    ## TODO: §7.4.4.  encryption-required
    my $mechanism = $self->attr("{}mechanism");
    return $self->send_failure("invalid-mechanism" => $conn)
        unless $saslmgr->is_mechanism_supported($mechanism);

    ## we don't support it for now
    my $opts = { no_integrity => 1 };
    $saslmgr->mechanism($mechanism);
    my $sasl_conn = $saslmgr->server_new("xmpp", $vhost->server_name, $opts);
    $conn->{sasl} = $sasl_conn;

    my $init = $self->first_child;
    if (!$init or $init eq '=') {
        $init = '';
    }
    else {
        $init = $self->decode($init);
    }

    $sasl_conn->server_start(
        $init => sub { $self->send_reply($conn->{sasl}, shift() => $conn) },
    );
}

sub send_challenge {
    my $self = shift;
    my ($challenge, $conn) = @_;

    $conn->log->debug("Sending Challenge: $challenge");
    my $enc_challenge = $self->encode($challenge);
    my $xml = "<challenge xmlns='urn:ietf:params:xml:ns:xmpp-sasl'>$enc_challenge</challenge>";
    $conn->xmllog->info($xml);
    $conn->write(\$xml);
}

sub send_failure {
    my $self = shift;
    my ($error, $conn) = @_;
    $conn->log->debug("Sending error: $error");
    my $xml = <<EOF;
<failure xmlns='urn:ietf:params:xml:ns:xmpp-sasl'><$error/></failure>
EOF
    $conn->xmllog->info($xml);
    $conn->write(\$xml);
    return;
}

sub ack_success {
    my $self = shift;
    my ($sasl_conn, $challenge, $conn) = @_;

    my $username = $sasl_conn->answer('username') || $sasl_conn->answer('user');
    my $sname = $conn->vhost->name;
    unless ($username && $sname) {
        $conn->log->error("Couldn't bind to a jid, declining.");
        $self->send_failure("not-authorized" => $conn);
        return;
    }
    my $authenticated_jid = "$username\@$sname";
    $sasl_conn->set_authenticated_jid($authenticated_jid);

    my $xml;
    if (defined $challenge) {
        my $enc = $challenge ? $self->encode($challenge) : "=";
        $xml = "<success xmlns='urn:ietf:params:xml:ns:xmpp-sasl'>$enc</success>";
    }
    else {
        $xml = "<success xmlns='urn:ietf:params:xml:ns:xmpp-sasl'/>";
    }
    $conn->xmllog->info($xml);
    $conn->write(\$xml);
    if (($sasl_conn->property('ssf') || 0) > 0) {
        $conn->log->info("SASL: Securing socket");
        $conn->log->warn("This will probably NOT work");
        $sasl_conn->securesocket($conn);
    }
    else {
        $conn->log->info("SASL: Not securing socket");
    }
    $conn->restart_stream;
}

sub encode {
    my $self = shift;
    my $str  = shift;
    return encode_base64($str, '');
}

sub decode {
    my $self = shift;
    my $str  = shift;
    return decode_base64($str);
}

sub send_reply {
    my $self = shift;
    my ($sasl_conn, $challenge, $conn) = @_;

    if (my $error = $sasl_conn->error) {
        $self->send_failure("not-authorized" => $conn);
    }
    elsif ($sasl_conn->is_success) {
        $self->ack_success($sasl_conn, $challenge => $conn);
    }
    else {
        $self->send_challenge($challenge => $conn);
    }
    return;
}

1;
