#!/usr/bin/perl
#
# foobarable's Jabber Proxy
#

BEGIN {
    $^P |= 0x01 if $ENV{TRACE_DJABBERD};
}

use strict;
use lib 'lib';
use FindBin qw($Bin);
use Getopt::Long;

use Client;
use DJabberd;
use DJabberd::Delivery::Proxy;
use DJabberd::Authen::Proxy;
use DJabberd::PresenceChecker::Local;
use DJabberd::RosterStorage::Proxy;
#use DJabberd::Plugin::MUC;
#use DJabberd::Plugin::VCard::SQLite;


my $daemonize;
Getopt::Long::GetOptions(
                         'd|daemon'       => \$daemonize,
                         );

#my $vcard = DJabberd::Plugin::VCard::SQLite->new;
#$vcard->set_config_storage("$Bin/roster.sqlite");
#$vcard->finalize;

#my $muc = DJabberd::Plugin::MUC->new;
#$muc->set_config_subdomain("conference");
#$muc->finalize;

my $vhost = DJabberd::VHost->new(
                                 server_name => 'milk-and-cookies.net',
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
                           old_ssl   => 1,
                           );

$server->add_vhost($vhost);
$server->run;


1;


