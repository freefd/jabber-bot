package plugins::juickdiff;

use strict;
use warnings;
use Exporter;
use LWP::UserAgent;
use Encode;
use utf8;
use FindBin qw($Bin);
use Digest::MD5;
use Text::Diff;

use vars qw(@ISA @EXPORT $VERSION);
$VERSION = '0.02';
@ISA = ('Exporter');
@EXPORT = qw( myINIT cache juickDiff );

my %config = (
	paths => {
		subs_folder => $Bin . "/plugins/juickdiff/",
	},

	useragent => "Mozilla/5.0 (Windows; U; Windows NT 5.1; ru; rv:1.8.0.2) Gecko/20060308 Firefox/1.5.0.4 Beta",
);

sub myINIT {
	main::registerEvent('^\.(?:жд|jd)\s+(.+)$', \&juickDiff);
	main::registerHelp(".jd или .жд - juickdiff.");
}


sub cache {}

sub juickDiff {
	my ($self, $juickUser) = @_;
	my $result;
	my $md5 = Digest::MD5->new;
	my $ua = LWP::UserAgent->new();
	   $ua->agent($config{useragent});

	if (-e "$config{paths}{subs_folder}$juickUser") {
		open FILE, "$config{paths}{subs_folder}$juickUser" || return "Ошибка: $!";
		my @oldSubs = <FILE>;
		   chomp @oldSubs;
		   @oldSubs = sort @oldSubs;
		close FILE;
		my @newSubs = sort split /\n/, _getSubscribers($juickUser);

		my ($oldSubs, $newSubs);
		$md5->add($_) for @oldSubs;
		$oldSubs = $md5->hexdigest;
		$md5->reset;
		$md5->add($_) for @newSubs;
		$newSubs = $md5->hexdigest;

		$result .= "\nold md5sum: " . $oldSubs . "\nnew md5sum: " . $newSubs . "\n";

		if ($oldSubs eq $newSubs) {

			$result = "Без изменений";

		} else {
			@newSubs = map { "$_\n" } @newSubs;
			@oldSubs = map { "$_\n" } @oldSubs;

			my $diff = diff \@oldSubs, \@newSubs;
			$diff =~ s{^(?:\-{3}|\+{3}|\@{2}|\s).+?\n}{}gim;
			my @diff = sort split /\n/, $diff;

			open FILE, ">", "$config{paths}{subs_folder}$juickUser" || return "Ошибка: $!";
			print FILE @newSubs;
			close FILE;

			$result = qq{=== subscribers difference ===\n\n@{[ join "\n", @diff ]}\n\n=== end of list ===};
		}
	} else {
		open FILE, ">", "$config{paths}{subs_folder}$juickUser" || return "Ошибка: $!";
		print FILE @{[ map { "$_\n" } sort split /\n/, _getSubscribers($juickUser) ]};
		close FILE;
		$result = "Это выглядит как первый запуск по данному пользователю.";
	}
	$result;
}


sub _getSubscribers {
	my $juickUser = shift;
	my $response = myGET("http://juick.com/$juickUser/friends");
	if ($response !~ /^\d{3}/) {
		$response =~ s{\n}{}gi;
		my $div = $1 if $response =~ /My readers \(\d+\)(.+?)<\/p>/s;
		$div =~ s{(,\s+|<br/>)}{\n}g;
		$div =~ s{<.+?>}{}gi;
		$div;
	} else {
		"Ответ сервера: $response. Попробуйте повторить запрос позже.";
	}
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

1;
