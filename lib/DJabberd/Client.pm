package DJabberd::Client;

use strict;
use warnings;

require DJabberd::Plugin;
use base 'DJabberd::Plugin';

### this plugin sets up a bot and subscribes any connecting user to it
### therefor, we need to include these libraries
# use Djabberd::Callback;
# use DJabberd::Bot::Demo;
# use DJabberd::Subscription;
# use DJabberd::RosterStorage;

### initialize a logger
our $logger = DJabberd::Log->get_logger();

sub register {
    my($self, $vhost) = @_;
    
    $vhost->register_hook("HandleStanza",              \&on_handle_stanza);

}




sub on_handle_stanza {
	$logger->debug("Stanza received");
}


1;
