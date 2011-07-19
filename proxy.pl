#!/usr/bin/perl
#
# foobarable's Jabber Proxy
#
package Proxy;

BEGIN {
    $^P |= 0x01 if $ENV{TRACE_DJABBERD};
}

use lib 'lib';
use vars qw($DEBUG $daemonize $conffile $logconf);
use Getopt::Long;

BEGIN {
    # We need to set up the logger before we "use DJabberd", because
    # most of the DJabberd libs will immediately make calls into
    # DJabberd::Log.

    $DEBUG = 0;
    $daemonize = 0;
    $conffile = "proxy.conf";
    $logconf = undef;

    Getopt::Long::GetOptions(
        'd|daemon'     => \$daemonize,
        'debug=i'      => \$DEBUG,
        'conffile=s'   => \$conffile,
        'logconf=s'    => \$logconf,
    );

    my @try_logconf_conf = ();
    if (defined($logconf)) {
        die "Can't find logging configuration file $logconf" unless -e $logconf;
        @try_logconf_conf = ( $logconf );
    }
    else {
        @try_logconf_conf = ( "etc/log.conf", "/etc/djabberd/log.conf", "etc/log.conf.default" );
    }
    use DJabberd::Log;
    DJabberd::Log->set_logger(@try_logconf_conf);
}

use FindBin qw($Bin);
#my $vcard = DJabberd::Plugin::VCard::SQLite->new;
#$vcard->set_config_storage("$Bin/roster.sqlite");
#$vcard->finalize;

#my $muc = DJabberd::Plugin::MUC->new;
#$muc->set_config_subdomain("conference");
#$muc->finalize;
use Proxy::Client;
use DJabberd;
use DJabberd::Log;
use DJabberd::Delivery::Proxy;
use DJabberd::Authen::Proxy;
use DJabberd::PresenceChecker::Local;
use DJabberd::RosterStorage::Proxy;
#use DJabberd::Plugin::MUC;
#use DJabberd::Plugin::VCard::SQLite;
our $logger = DJabberd::Log->get_logger();
print "host " .Proxy::Config::get_host();
$logger->info("host ",Proxy::Config::get_host()); # das mit dem logger geht einfach noch nicht.. ich glaube das liegt daran, dass wir teil von djabberd sein muessen
my $vhost = DJabberd::VHost->new(
                                 server_name => Proxy::Config::get_host(),
                                 require_ssl => 0,
                                 s2s       => 0,
                                 plugins   => [
                                               DJabberd::Authen::Proxy->new,
                                               DJabberd::RosterStorage::Proxy->new,
					       #$vcard,
					       #$muc,
                                               DJabberd::Delivery::Proxy->new,
                                               ],
                                 );

my $server = DJabberd->new(
                           daemonize => $daemonize,
                           old_ssl   => 0,
                           );

$server->add_vhost($vhost);
#TODO: register user from config..

$server->run;

