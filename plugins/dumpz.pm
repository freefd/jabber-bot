package plugins::dumpz;

use strict;
use warnings;
use Exporter;
use LWP;
use Encode;
use HTTP::Request::Common;
use JSON::XS;
use utf8;
use FindBin qw($Bin);
use vars qw(@ISA @EXPORT $VERSION);
$VERSION = '0.02';
@ISA = ('Exporter');
@EXPORT = qw( myINIT cache dumpz );

my %config = (

	paths => {
		dumpz_folder => $Bin . "/plugins/dumpz/",
	},

	URI => "http://dumpz.org/api/upload/",

);

sub myINIT {
	main::registerEvent('^\.(?:d|д)\s+\*(.+?)\s+(.+)$', \&dumpz);
	main::registerHelp('.d dump_text или .д код');
}

sub cache {}

sub dumpz {
	my %args = (@_);
	my $result;
	my $lwp = LWP::UserAgent->new;
	$lwp->timeout(40);
	my $request = POST "$config{URI}",
					[
								'lexer'	=> $args{saved1},
								'code'	=> $args{saved2},
								'comment' => '',
					];
		$request->header('pragma' => 'no-cache', 'max-age' => '0');
	my $response = $lwp->request($request);

	open DUMP, ">:utf8", $config{paths}{dumpz_folder} . $args{senderJID} . "_" . $args{saved1} . "_" . time . ".txt" || die $!;
	print DUMP $args{saved2};
	close DUMP;

	if ($response->status_line eq "200 OK") {
		my $jsonHash = decode_json $response->content;
		$result = ${$jsonHash}{url};
	} else {
		$result = "Error:" . $response->status_line;
	}
	$result;
}

1;
