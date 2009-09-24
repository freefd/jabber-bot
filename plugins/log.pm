package plugins::log;

use strict;
use warnings;
use Exporter;
use utf8;
use FindBin qw($Bin);
use vars qw(@ISA @EXPORT $VERSION);
$VERSION = '0.02';
@ISA = ('Exporter');
@EXPORT = qw( myINIT accessLog );

binmode STDOUT, ":utf8";

my %config = (
	paths => {
		accessLog => $Bin . "/logs/",
	},
);

sub myINIT {}
sub cache {}

# jid - string [18/Oct/2000:13:55:36] resource

sub accessLog {
	my ($string, $JID, $resource) = @_;
	#     0    1    2     3     4    5
	my ($sec,$min,$hour,$mday,$mon,$year) = (localtime(time))[0..5];
	my @abbr = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
	$year += 1900;

	$sec = "0$sec" if $sec < 10;
	$min = "0$min" if $min < 10;
	$hour = "0$hour" if $hour < 10;

	open LOG, ">>:utf8", $config{paths}{accessLog} . $JID . ".log" || die $!;
	print LOG "$JID - \"$string\" [$mday/$abbr[$mon]/$year:$hour:$min:$sec] $resource\n";
	close LOG;
}

1;
