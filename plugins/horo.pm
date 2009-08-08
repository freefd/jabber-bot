package plugins::horo;

use strict;
use warnings;
use Exporter;
use LWP;
use Encode;
use HTTP::Request;
use utf8;
use FindBin qw($Bin);
use vars qw(@ISA @EXPORT $VERSION %horo);
$VERSION = '0.02';
@ISA = ('Exporter');
@EXPORT = qw( myINIT cache );

my %config = (

	cache_time => "06:00",

	paths => {
		cache_folder => $Bin . "/plugins/horo/",
	},

	horoscope => {
		"овен" => "aries",
		"телец" => "taurus",
		"близнецы" => "gemini",
		"рак" => "cancer",
		"краб" => "cancer",
		"лев" =>"leo",
		"дева" => "virgo",
		"весы" => "libra",
		"скорпион" => "scorpio",
		"стрелец" => "sagittarius",
		"козерог" => "capricorn",
		"водолей" => "aquarius",
		"рыбы" => "pisces",
	},

	horo => ["aries", "taurus", "gemini", "cancer", "leo", "virgo", "libra", "scorpio", "sagittarius", "capricorn", "aquarius", "pisces"],
);

sub myINIT {
	%horo = map { $_ => 1 } @{$config{horo}};
	main::registerEvent('^\.(?:h|г)\s+(.+?)\s+(.+?)$', \&horo);
	main::registerHelp('.h gemini today или .г рак завтра - расскажет Вам гороскоп по указанному знаку зодиака на сегодня или завтра.');
}

sub horo {
	my %args = (@_);
	my ($type, $day) = ($args{saved1}, $args{saved2});
	my $result;

	if (!exists $config{horoscope}{$type} && !exists $horo{$type}) {
		$result = "нет такого знака зодиака...";
	} else {

		if ($day =~ /(сегодня|today|седня|сёдня|сёня|сеня|tod)/) {
			$day = "tod";
		} elsif ($day =~ /(завтра|tomorrow|завтро|затра|завра|звтра|завтр|tom)/) {
			$day = "tom";
		} else {
			$result = "не распознал день, повторите запрос.";
		}

		if ($day eq "tod" || $day eq "tom") {

			$type = $config{horoscope}{$type} || $type;

			if (-e $config{paths}{cache_folder} . $day . "/" . $type) {

				open CACHE, "<:utf8", $config{paths}{cache_folder} . $day . "/" . $type || die $!;
				{
					local $/;
					$result = <CACHE>;
				}
				close CACHE;
				my @t = localtime( (stat $config{paths}{cache_folder} . $day . "/" . $type)[9] );
				$result .= "\ncached at " . sprintf "%02u/%02u/%02u %02u:%02u:%02u",  $t[3], $t[4] + 1, $t[5] % 100, $t[2], $t[1], $t[0];
			} else {
				my $lwp = LWP::UserAgent->new;
				$lwp->timeout(20);
				my $r = HTTP::Request->new(GET => "http://horo.ru/lov/$day/$type.html");
				$r->header('pragma' => 'no-cache', 'max-age' => '0');
				my $response = $lwp->request($r);
				if ($response->is_success) {
					my $content = decode "utf-8", $response->content;
					$content =~ s{[\n\r]+}{}gi;
					$content =~ s{^\s+}{}i;
					$content =~ s{\s+$}{}i;

					if ($content =~ /<!--date (\d{2}.\d{2}\.\d{4})-->\s*<\/div>\s*<div class="int-text">\s*<h2>(.+?)\.\s+Общий гороскоп<\/h2>\s*<!--r.daily.tom._file_.text-->\s*(.+?)\s*<\/div>/){
						$result .= "Гороскоп для $2 на $1: $3\n\nvia Horo.ru";
					}
				} else {
					$result = $response->status_line . ". Повторите запрос.";
				}
			}
		}
	}
	$result;
}

sub cache {
	for my $type (@{$config{horo}}) {
		for my $day (qw(tod tom)) {
			#print $config{paths}{cache_folder} . $day . "/" . $type . "\n";
			my $lwp = LWP::UserAgent->new;
			$lwp->timeout(20);
			my $r = HTTP::Request->new(GET => "http://horo.ru/lov/$day/$type.html");
			$r->header('pragma' => 'no-cache', 'max-age' => '0');
			my $response = $lwp->request($r);
			my $result;
			if ($response->is_success) {
				my $content = decode "utf-8", $response->content;
				$content =~ s{[\n\r]+}{}gi;
				$content =~ s{^\s+}{}i;
				$content =~ s{\s+$}{}i;

				if ($content =~ /<!--date (\d{2}.\d{2}\.\d{4})-->\s*<\/div>\s*<div class="int-text">\s*<h2>(.+?)\.\s+Общий гороскоп<\/h2>\s*<!--r.daily.tom._file_.text-->\s*(.+?)\s*<\/div>/){
					$result = "Гороскоп для $2 на $1: $3\n\nvia Horo.ru";
				}
			} else {
				$result = "Ответ сервера: " . $response->status_line;
			}

			open CACHE, ">:utf8", $config{paths}{cache_folder} . $day . "/" . $type || die $!;
			print CACHE $result;
			close CACHE;
		}
	}
}

1;
