#!/usr/bin/perl
#
# foobarable's Jabber Proxy
#
package xmpproxy;

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
    $conffile = "proxy.xml";
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


#my $muc = DJabberd::Plugin::MUC->new;
#$muc->set_config_subdomain("conference");
#$muc->finalize;

use DJabberd;
use DJabberd::Log;
use DJabberd::ClientHandler;
use DJabberd::Plugin::Ping;
use DJabberd::Delivery::Proxy;
use DJabberd::Delivery::Local;
use DJabberd::Delivery::OfflineStorage;
use DJabberd::Delivery::OfflineStorage::InMemoryOnly;
use DJabberd::Authen::Proxy;
use DJabberd::PresenceChecker::Local;
use DJabberd::RosterStorage::Proxy;
use xmpproxy::UserDB;
#use DJabberd::Plugin::MUC;
#use DJabberd::Plugin::VCard::SQLite;

our $logger = DJabberd::Log->get_logger();


#create plugins
my $auth = DJabberd::Authen::Proxy->new();
my $roster = DJabberd::RosterStorage::Proxy->new();
my $proxydelivery = DJabberd::Delivery::Proxy->new();
my $localdelivery = DJabberd::Delivery::Local->new();
my $offlinedelivery = DJabberd::Delivery::OfflineStorage::InMemoryOnly->new();


my $vhost = DJabberd::VHost->new(
                                 server_name => DJabberd::Config::Config::get_host(),
				 
				 #TODO: read this from options file
                                 require_ssl => 0,
				 
				 #we don't need server to server communication in a proxy server
                                 s2s       => 0,

				 #register required plugins
                                 plugins   => [
					       #$client,
                                               $auth, 
                                               $roster,
					       $proxydelivery,
					       $localdelivery,
					       $offlinedelivery,
					       DJabberd::Plugin::Ping,
					       #TODO:
					       #$vcard,
					       #$muc,
                                               ],
                                 );
		
#we want a global userdb and every user needs a reference to the vhost because DJabberd::Queue requires it. Maybe find something better than this..
our $userdb = new xmpproxy::UserDB($vhost);
my $server = DJabberd->new(
                           daemonize => $daemonize,
                           old_ssl   => 1,
                           );

$server->add_vhost($vhost);
#TODO: register user from config..
$server->run;


