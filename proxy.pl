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


#package DJabberd::Authen::SixApart;
#use strict;
#use base 'DJabberd::Authen';
#use Net::LDAP;
#
#sub can_retrieve_cleartext { 0 }
#
#sub check_cleartext {
#    my ($self, $cb, %args) = @_;
#   my $user = $args{username};
#    my $pass = $args{password};
#    my $conn = $args{conn};
#
#    unless ($user =~ /^\w+$/) {
#        $cb->reject;
#        return;
#    }
#
#    my $ldap = Net::LDAP->new( $SixApart::LDAP_SERVER ) or die "$@";
#    my $dn   = "uid=$user,ou=People,dc=sixapart,dc=com";
#    my $msg  = $ldap->bind($dn, password => $pass, version => 3);
#    if ($msg && !$msg->is_error) {
#        $cb->accept;
#    } else {
#        $cb->reject;
#    }
#}


#package DJabberd::RosterStorage::SixApart;
#use strict;
#use base 'DJabberd::RosterStorage::SQLite';
#
#sub get_roster {
#    my ($self, $cb, $jid) = @_;
#    # cb can '->set_roster(Roster)' or decline
#
#    my $myself = lc $jid->node;
#    warn "SixApart loading roster for $myself ...\n";
#
#    my $on_load_roster = sub {
#        my (undef, $roster) = @_;
#
#        my $pre_ct = $roster->items;
#        warn "  $pre_ct roster items prior to population...\n";
#
#        # see which employees already in roster
#        my %has;
#        foreach my $it ($roster->items) {
#            my $jid = $it->jid;
#            next unless $jid->as_bare_string =~ /^(\w+)\@sixapart\.com$/;
#            $has{lc $1} = $it;
#        }
#
#        # add missing employees to the roster
#        my $emps = _employees();
#        foreach my $uid (keys %$emps) {
#            $uid = lc $uid;
#            next if $uid eq $myself;
#
#            my $emp = $emps->{$uid};
#            my $ri = $has{$uid} || DJabberd::RosterItem->new(jid  => "$uid\@sixapart.com",
#                                                             name => ($emp->{displayName} || $emp->{cn}),
#                                                             groups => ["SixApart"]);
#
#
#            $ri->subscription->set_from;
#            $ri->subscription->set_to;
#            $roster->add($ri);
#        }
#
#        my $post_ct = $roster->items;
#        warn "  $post_ct roster items post population...\n";
#
#        $cb->set_roster($roster);
#    };
#
#    my $cb2 = DJabberd::Callback->new({set_roster => $on_load_roster,
#                                      decline    => sub { $cb->decline }});
#    $self->SUPER::get_roster($cb2, $jid);
#}

#my $last_emp;
#my $last_emp_time = 0;  # unixtime of last ldap suck (ldap server is slow sometimes, so don't always poll)
1;


