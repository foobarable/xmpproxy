package DJabberd::Client::Message;
use strict;
use base qw(DJabberd::Message);
use Data::Dumper;
$Data::Dumper::Maxdepth = 3;

sub on_recv_from_server {
	my ($self, $conn) = @_;
	
	my $to = $self->to_jid;
	if (! $to) {
		warn "Can't process a message to nobody.\n";
	 	$conn->close;
		return;
	}
	my $newto = DJabberd::JID->new($xmpproxy::userdb->{proxy2local}->{$to->as_bare_string});
	$self->set_to($newto);
	$DJabberd::Stats::counter{"c2s-Message"}++;
	$self->deliver;
}

sub process {
    my ($self, $conn) = @_;
    die "Can't process a to-server message?";
}


1;
