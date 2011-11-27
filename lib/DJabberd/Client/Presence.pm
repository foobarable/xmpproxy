package DJabberd::Client::Presence;
use strict;
use base qw(DJabberd::Presence);
use Data::Dumper;
use DJabberd::Connection::ClientOut;

sub on_recv_from_server {
	my ($self, $conn) = @_;
	
	my $to = $self->to_jid;
	if (! $to) {
		warn "Can't process a presence to nobody.\n";
	 	$conn->close;
		return;
	}
	my $newto = DJabberd::JID->new($xmpproxy::userdb->{proxy2local}->{$to->as_bare_string});
	$self->set_to($newto);
	$DJabberd::Stats::counter{"c2s-presence"}++;
	$self->deliver;
}

sub process {
    my ($self, $conn) = @_;
    die "Can't process a to-server message?";
}



sub initial_presence {
    my $self = shift;
    my $conn = shift;
    my $message = shift || 'Default Message';
    my $xml = qq{<presence><status>$message</status></presence>};
    $conn->log_outgoing_data($xml);
    $conn->write($xml);
}


1;
