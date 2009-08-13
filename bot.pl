#!/usr/bin/perl

use strict;
use warnings;
use Net::XMPP;
use Net::Ping;
use utf8;
use Module::Find;
use Module::Load;
use Time::HiRes;
use FindBin qw($Bin);

my (%events, @help);

my %config;

my @configs = (
    "$Bin/wbot.conf",
    $ENV{HOME} . '/.config/wbot/wbot.conf',
    '/etc/wbot.conf',
);

foreach my $config (@configs) {
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

my $clientObj = new Net::XMPP::Client(debuglevel => 0);

$clientObj->SetCallBacks(
			onauth => \&onAuth,
		);

$clientObj->SetMessageCallBacks(
			chat => \&messageChatCB,
		);

$clientObj->Execute(
					hostname => $config{hostname},
					username => $config{username},
					password => $config{password},
					resource => $config{resource},
			);

$clientObj->Disconnect();

sub onAuth {
		$clientObj->PresenceSend(
								 show		=> $config{status},
								 priority	=> 10,
								);
}

sub messageChatCB {
    my ($sid,$mes) = @_;
    my $sender=$mes->GetFrom();
    my $body=$mes->GetBody();
    my $thread=$mes->GetThread();
    my $JID = new Net::XMPP::JID($sender);

    my $senderJID=$JID->GetJID("base");
	my $senderResource=$JID->GetResource();
    my $reply='';

	for ($body) {
		accessLog($body, $senderJID, $senderResource);
		if (length > 1 && substr($_, 0, 1) eq ".") {
			foreach my $key (keys %events) {
				if (/$key/i) {
					$reply = $events{$key}->(
											saved1 => $1,
											saved2 => $2,
											saved3 => $3,
											senderJID => $senderJID,
											senderResource => $senderResource,
											ownerJID => $config{ownerJID},
										);
					last;
				}
			}
		} else {
			$reply = "\n" . join "\n", @help if /^(?:\.?help|\?|хелп|\.h)/i;

			if (/^(?:exit|quit)$/i) {
				if ($senderJID eq $config{ownerJID}) {
                	$clientObj->Disconnect();
                	exit;
                } else {
                	$reply = "Я не знаю Вас.";
				}
			}

			if (/^ping\s+([0-9a-z.]+)$/i) {
				my $host = $1;
				my ($ret, $duration, $ip);
				my $p = Net::Ping->new("syn");

				$p->hires();
				($ret, $duration, $ip) = $p->ping($host);
				if ($ret) {
					$reply = sprintf("$host [ip: $ip] is alive (packet return time: %.2f ms)", 1000 * $duration);
				} else {
					$reply = "Не получается.";
				}
    			$p->close();
			}
		}
	}

	$reply && $clientObj->MessageSend(
		to=>$sender,
		subject=>"",
		body=> $reply,
		type => 'chat',
		thread => $thread,
	);
}

__END__

=head1 AUTHOR

Fd <fd@freefd.info> L<http://freefd.info/>

=head1 COPYRIGHT

Copyright (c) <2009> <Fd>

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut
