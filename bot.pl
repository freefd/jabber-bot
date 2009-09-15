#!/usr/bin/perl
use strict;
use utf8;
use AnyEvent;
use AnyEvent::XMPP::Client;
use AnyEvent::XMPP::Util qw/split_jid/;
use Net::Ping;
use Module::Find;
use Module::Load;
use Time::HiRes;
use FindBin qw($Bin);

binmode STDOUT, ":utf8";

my (%events, @help);

my %config;

my @configs = (
    "$Bin/wbot.conf",
    $ENV{HOME} . '/.config/wbot/wbot.conf',
    '/etc/wbot.conf',
);

foreach my $config (sort @configs) {
	if (-e $config && -f $config && -r $config) {
		open CONFIG, "<", $config || die $!;
		flock CONFIG, 2;
		while (<CONFIG>){
			chomp;
			s/#.*//;  s/^\s+//;
			s/\s+$//; s/\[.*\]//;
			next unless length;
			my ($var, $value) = split /\s*=\s*/, $_, 2;
			$config{$var} = $value;
		}
		close CONFIG;
		last;
	}
}

die "%config is empty" if $config{ownerJID} eq '' || $config{hostname} eq '' || $config{username} eq '' || $config{password} eq '';

map { load $_; $_->import(); $_->myINIT();} findallmod plugins;

sub registerEvent {
    my ($type, $handler) = @_;
    $events{$type} = $handler;
}

sub registerHelp {
    push @help, shift;
}

my $j = AnyEvent->condvar;
my $clientObj = AnyEvent::XMPP::Client->new (debug => 0);
$clientObj->add_account($config{username} . '@' . $config{hostname} . '/' . $config{resource}, $config{password});
$clientObj->reg_cb(

	session_ready => sub {
		my ($client, $acc) = @_;
		$client->set_presence('chat', undef, 10);
	},

	contact_request_subscribe => sub {
		my ($client, $acc, $roster, $contact) = @_;
		$contact->send_subscribed;
		$contact->send_subscribe;
	},

	contact_subscribed => sub {
		my ($client, $acc, $roster, $contact ) = @_;
		$client->send_message("\n@{[ join qq{\n}, @help ]}" => $contact->jid, undef, 'chat');
	},

	disconnect => sub {
		my ($client, $acc, $h, $p, $reas) = @_;
		#print "disconnect ($h:$p): $reas\n";
		$j->broadcast;
   },

   error => sub {
		my ($client, $acc, $err) = @_;
		#print "ERROR: " . $err->string . "\n";
   },

   message => sub {
		my ($client, $acc, $msg) = @_;
		my ($userName, $hostName, $senderResource) = split_jid($msg->from);
		my $reply='';
		for ($msg->any_body) {
			accessLog($msg->any_body, $userName . '@' . $hostName, $senderResource) if $msg->any_body ne '';
			if (length > 1 && substr($_, 0, 1) eq ".") {
				foreach my $key (keys %events) {
					if (/$key/is) {
						$reply = $events{$key}->(
									saved1 => $1,
									saved2 => $2,
									saved3 => $3,
									senderJID => $userName . '@' . $hostName,
									senderResource => $senderResource,
									ownerJID => $config{ownerJID},
								  );
						last;
					}
				}
			} else {
				$reply = "\n" . join "\n", @help if /^(?:\.?help|\?|хелп|\.h)/i;

				if (/^(?:exit|quit)$/i) {
					if ($config{ownerJID} eq $userName . '@' . $hostName) {
						$clientObj->disconnect;
						exit;
					} else {
						$reply = "Я не знаю Вас.";
					}
				}

				if (/^ping\s+([0-9a-z.]+)$/i) {
					my $host = $1;
					my ($ret, $duration, $ip);
					my $pingObj = Net::Ping->new("syn");

					$pingObj->hires();
					($ret, $duration, $ip) = $pingObj->ping($host);
					if ($ret) {
						$reply = sprintf("$host [ip: $ip] is alive (packet return time: %.2f ms)", 1000 * $duration);
					} else {
						$reply = "Не получается.";
					}
					$pingObj->close();
				}
			}
		}
		$client->send_message($reply => $msg->from, undef, 'chat');
	}
);

$clientObj->start;
$j->wait;
