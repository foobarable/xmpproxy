package DJabberd::Client::Presence;
use DJabberd::Connection::ClientOut;

sub initial_presence {
    my $self = shift;
    my $conn = shift;
    my $message = shift || 'Default Message';
    my $xml = qq{<presence><status>$message</status></presence>};
    $conn->log_outgoing_data($xml);
    $conn->write($xml);
}


1;
