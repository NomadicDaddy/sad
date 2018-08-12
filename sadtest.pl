=for PDK_OPTS
   --exe sadtest.exe --trim-implicit --shared private --force --dyndll --norunlib --verbose --freestanding --nologo --icon "d:/adminware/artwork/aw.ico"
   --info "CompanyName      = adminware, llc;
           FileDescription  = sadtest - Tester for SpamAssassin Daemon for Win32;
           Copyright        = Copyright © 2004-2005 adminware, llc.  All rights reserved.;
           LegalCopyright   = Copyright © 2004-2005 adminware, llc.  All rights reserved.;
           LegalTrademarks  = adminware is a trademark of adminware, llc.  SpamAssassin is a trademark of Apache Software Foundation;
           SupportURL       = http://adminware.com/sad/;
           InternalName     = sadtest;
           OriginalFilename = sadtest;
           ProductName      = sadtest;
           Language         = English;
           FileVersion      = 1.02.1.1;
           ProductVersion   = 1.02.1.1"
   sadtest.pl
=cut
#   --add=IO::Socket::INET;Time::HiRes

use strict;
use IO::Socket;
use Time::HiRes qw(time);

my ($host, $port, $cycle, $interval, $client);
die "\nUSAGE: $0 [host] [port] [cycle] [interval]\n" unless (@ARGV == 4);
($host, $port, $cycle, $interval) = @ARGV;

my $startMark = time();

for (1..$cycle) {

	$client = IO::Socket::INET->new(Proto => "tcp", PeerAddr => $host, PeerPort => $port) or die "can't connect to port $port on $host: $!";
	$client->autoflush(1);
	print $client "z\r\n";
	print <$client>;
	close $client;

	$client = IO::Socket::INET->new(Proto => "tcp", PeerAddr => $host, PeerPort => $port) or die "can't connect to port $port on $host: $!";
	$client->autoflush(1);
	print $client "VERSION\r\n";
	print <$client>;
	close $client;

	$client = IO::Socket::INET->new(Proto => "tcp", PeerAddr => $host, PeerPort => $port) or die "can't connect to port $port on $host: $!";
	$client->autoflush(1);
	print $client "PING\r\n";
	print <$client>;
	close $client;

	$client = IO::Socket::INET->new(Proto => "tcp", PeerAddr => $host, PeerPort => $port) or die "can't connect to port $port on $host: $!";
	$client->autoflush(1);
	print $client "CHECK C:\\Mail-SpamAssassin-3.0.2\\sample-nonspam.txt\r\n";
	print <$client>;
	close $client;

	$client = IO::Socket::INET->new(Proto => "tcp", PeerAddr => $host, PeerPort => $port) or die "can't connect to port $port on $host: $!";
	$client->autoflush(1);
	print $client "CHECK C:\\Mail-SpamAssassin-3.0.2\\sample-spam.txt\r\n";
	print <$client>;
	close $client;

	sleep($interval);

}

my $endMark = time();
my $elapsedTime = $endMark - $startMark;

print "\n";
print "# OF CYCLES   : ", $cycle, "\n";
print "INTERVAL      : ", $interval, "\n";
print "ELAPSED TIME  : ", $elapsedTime, "\n";
print "AVE PER CYCLE : ", $elapsedTime / $cycle, "\n";
