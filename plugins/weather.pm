package plugins::weather;

use strict;
use warnings;
use Exporter;
use XML::Simple;
use XML::RSS;
use LWP::UserAgent;
use Encode;
use utf8;
use FindBin qw($Bin);
use vars qw(@ISA @EXPORT $VERSION);
$VERSION = '0.02';
@ISA = ('Exporter');
@EXPORT = qw( myINIT cache );

my %config = (
	paths => {
		citiesDB => "$Bin/xml/gmbartlist.xml",
		jidsDB => "$Bin/xml/jids.xml",
	},

	lwpTimeout => 20,
);

my (%citiesdb, %users);

sub myINIT {
	%citiesdb = loadCodes($config{paths}{citiesDB});
	%users = loadJIDbase($config{paths}{jidsDB});
	main::registerEvent('^\.(?:п|w)\s+(.+)$', \&getWeather);
	main::registerEvent('^\.(?:п|w)$', \&getUserWeather);
	main::registerEvent('^\.(?:c|s|с)\s+(.+)$', \&saveCity);
	main::registerHelp('.w city или .п город - покажет погоду по указанному городу на ближайшие 24 часа.');
	main::registerHelp('.w или .п - покажет погоду по заранее сохранённому за Вашим JID городу на ближайшие 24 часа.');
	main::registerHelp('.s city или .с город - сохранение за Вашим JID указанного города.');
}

sub loadCodes {
	my $databasePath = shift;
	my %db;
	my $xsObj = XML::Simple->new();
	my $doc = $xsObj->XMLin($databasePath);
	$_->{n} = lc $_->{n}, $db{$_->{n}} = $_->{i} for @{$doc->{t}};
	return %db;
}

sub loadJIDbase {
	my $databasePath = shift;
	my %users = ();
	my $xsObj = XML::Simple->new();
	my $doc;
	if (-e $databasePath) {
	 	$doc = $xsObj->XMLin($databasePath);
		if (ref $doc->{user} eq "ARRAY") {
			$users{$_->{jid}} = lc $_->{town} for @{$doc->{user}};
		} elsif (ref $doc->{user} eq "HASH") {
			$users{$doc->{user}->{jid}} = lc $doc->{user}->{town};
		}
	} else {
		$xsObj->XMLout(
			\%{()},
			RootName => "users",
			OutputFile => $databasePath,
			XMLDecl => 1,
		);
	}
	undef $xsObj;
	return %users;
}

sub updateJIDbase {
	my ($databasePath, $jid, $town) = @_;

	my $xsObj = XML::Simple->new();
	my $doc = $xsObj->XMLin($databasePath);
	undef $xsObj;

	if (ref $doc->{user} eq "ARRAY") {
		my $nextId = scalar @{$doc->{user}};
	 	for (0.. @{$doc->{user}} - 1) {
 			$nextId = $_, last if $doc->{user}->[$_]->{jid} eq $jid;
 		}
 		$doc->{user}->[$nextId]->{jid} = $jid;
		$doc->{user}->[$nextId]->{town} = lc $town;
 	} else {
		if (exists $doc->{user}->{jid}) {
			my ($anotherJid, $anotherTown) = ($doc->{user}->{jid}, $doc->{user}->{town});

			%{$doc} = ();

			$doc->{user}->[0]->{jid} = $anotherJid;
			$doc->{user}->[0]->{town} = lc $anotherTown;

			$doc->{user}->[1]->{jid} = $jid;
			$doc->{user}->[1]->{town} = lc $town;
		} else {
			$doc->{user}->{jid} = $jid;
			$doc->{user}->{town} = lc $town;
		}
	}

	$xsObj = XML::Simple->new();
	$xsObj->XMLout(
		\%{$doc},
		RootName => "users",
		OutputFile => $databasePath,
		XMLDecl => 1,
	);
	undef $xsObj;
}

sub getWeather {
	my %args = (@_);
	my $result;
	$args{saved1} = lc $args{saved1};
	if (exists $citiesdb{$args{saved1}}) {
		my $response = myGET("http://informer.gismeteo.ru/rss/$citiesdb{$args{saved1}}.xml");
		if ($response !~ /^\d{3}/) {
			my $rssObj = new XML::RSS;
			$rssObj->parse($response);
			$result .= join '', map { "\n$_->{title} $_->{description}\n" } @{$rssObj->{items}};
			$result .= "\nvia Gismeteo.Ru";
		} else {
			$result = "Ответ сервера: $response. Попробуйте повторить запрос позже.";
		}
	} else {
		$result = "Город @{[ ucfirst $args{saved1} ]} в базе не найден.";
	}
	$result;
}

sub getUserWeather {
	my %args = (@_);
	my $result;
	if (exists $users{$args{senderJID}} && exists $citiesdb{$users{$args{senderJID}}}) {
		my $response = myGET("http://informer.gismeteo.ru/rss/$citiesdb{$users{$args{senderJID}}}.xml");
		if ($response !~ /^\d{3}/) {
			my $rssObj = new XML::RSS;
			$rssObj->parse($response);
			$result .= join '', map { "\n$_->{title} $_->{description}\n" } @{$rssObj->{items}};
			$result .= "\nvia Gismeteo.Ru";
		} else {
			$result = "Ответ сервера: $response. Попробуйте повторить запрос позже.";
		}
	} else {
		$result = "Я не знаю Ваш город.";
	}
	$result;
}

sub saveCity {
	my %args = (@_);
	my $result;
	my $city = lc $args{saved1};
	if (exists $citiesdb{$city}) {
		$result = "Для $args{senderJID} городом по умолчанию назначен @{[ ucfirst $city ]}.";
		updateJIDbase($config{paths}{jidsDB}, $args{senderJID}, $city);
		%users = loadJIDbase($config{paths}{jidsDB});
	} else {
		$result = "Город @{[ ucfirst $city ]} в базе не найден."
	}
	$result;
}


sub myGET {
	my $url = shift;
	my $lwpObj = LWP::UserAgent->new;
	$lwpObj->timeout($config{lwpTimeout});
	$lwpObj->env_proxy;
	my $requestObj = HTTP::Request->new(GET => $url);
	$requestObj->header('pragma' => 'no-cache', 'max-age' => '0');
	my $response = $lwpObj->request($requestObj);
	$response->is_success ? $response->content : $response->status_line;
}

sub cache {}
1;
