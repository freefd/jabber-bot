package plugins::rss;

use strict;
use warnings;
use Exporter;
use HTML::Entities;
use XML::RSS;
use LWP::UserAgent;
use Encode;
use utf8;
use FindBin qw($Bin);
use URI::Split qw(uri_split);

use vars qw(@ISA @EXPORT $VERSION);
$VERSION = '0.02';
@ISA = ('Exporter');
@EXPORT = qw( myINIT cache );

my %config = (
	functions => {
					bash => 'http://bash.org.ru/rss/',
					ibash => 'http://ibash.org.ru/rss.xml',
				 },

	events => {
				bash => '^\.(?:б|b)$',
				ibash => '^\.(?:й|i)$',
			  },

	count => 15,

	help => {
				bash => ".b или .б - последние 15 постов bash.org.ru.",
				ibash => '.i или .й - последние 15 постов ibash.org.ru.',
			},

	paths => {
		cache_folder => $Bin . "/plugins/rss/",
	},
);

sub myINIT {
	foreach my $key (keys %{$config{functions}} ) {
		no strict 'refs';
		*$key = sub { return getRSS($config{functions}{$key}) };
		main::registerEvent($config{events}{$key}, \&$key);
		main::registerHelp($config{help}{$key});
	}
}

sub getRSS {
	my $stream = shift;
	my $result = "\n";
	my %hash = reverse %{$config{functions}};

	if (-e $config{paths}{cache_folder} . $hash{$stream}) {

		open CACHE, "<:utf8", $config{paths}{cache_folder} . $hash{$stream} || die $!;
		{
			local $/;
			$result = <CACHE>;
		}
		close CACHE;
		my @t = localtime( (stat $config{paths}{cache_folder} . $hash{$stream})[9] );
		$result .= "\ncached at " . sprintf "%02u/%02u/%02u %02u:%02u:%02u",  $t[3], $t[4] + 1, $t[5] % 100, $t[2], $t[1], $t[0];
	} else {
		my $rssObj = new XML::RSS;
		$rssObj->parse(decode_entities myGET($stream)) || die $!;
		my $i = 0;
		foreach my $item ( @{ $rssObj->{items} } ) {
			$item->{description} =~ s{<br\s?\/?>\n?}{\n}gi;
			$result .= " $item->{title} \n$item->{description}\n\n";
			$i++;
			last if $i >= $config{count}-1;
		}
		$result .= "via " . (uri_split($stream))[1];
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

sub cache {
	foreach my $key (keys %{$config{functions}} ) {
		my $result = "\n";
		my $rssObj = new XML::RSS;
		$rssObj->parse(decode_entities myGET($config{functions}{$key})) || die $!;
		my $i = 0;
		foreach my $item ( @{ $rssObj->{items} } ) {
			$item->{description} =~ s{<br\s?\/?>\n?}{\n}gi;
			$result .= " $item->{title} \n$item->{description}\n\n";
			$i++;
			last if $i >= $config{count}-1;
		}
		$result .= "via " . (uri_split($config{functions}{$key}))[1];

		open CACHE, ">:utf8", $config{paths}{cache_folder} . $key || die $!;
		print CACHE $result;
		close CACHE;
	}
}

1;
