=for PDK_OPTS
   --exe sad.exe --shared private --force --clean --verbose --freestanding --nologo --icon "d:/adminware/artwork/aw.ico"
   --add=Getopt::Long;Config::IniFiles;IO::Socket::INET;IO::File;Mail::SpamAssassin;Mail::SpamAssassin::NoMailAudit
   --info "CompanyName      = adminware, llc;
           FileDescription  = sad - SpamAssassin Daemon for Win32;
           Copyright        = Copyright © 2004-2005 adminware, llc.  All rights reserved.;
           LegalCopyright   = Copyright © 2004-2005 adminware, llc.  All rights reserved.;
           LegalTrademarks  = adminware is a trademark of adminware, llc.  SpamAssassin is a trademark of Apache Software Foundation;
           SupportURL       = http://adminware.com/sad/;
           InternalName     = sad;
           OriginalFilename = sad;
           ProductName      = sad;
           Language         = English;
           FileVersion      = 0.110.291.1;
           ProductVersion   = 0.110.291.1"
   sad.pl
=cut

package PerlSvc;
our %Config = (ServiceName => 'sad');

our $awp = 'sad';
our $ver = '0.110.291.1';
our $cpy = 'Copyright © 2004-2005 adminware, llc.  All rights reserved.';

use strict;
#use warnings;
use Getopt::Long;
use vars qw($awp $ver $cpy $log $help $man $version $quiet $config %ini $siteRules $defRules $debug $cwd $spamTest $localhost $port $mailRoot $logConnects $logGMT $logClientNames $clientName $showBanner $rewrite $maxCheckSize $time_to_die $stop $client $removing);

# App-Specific Modules
use Config::IniFiles;
use Cwd qw(getcwd);
use POSIX qw(strftime);
use Win32::API;
use IO::Socket::INET;
use IO::Select;
use IO::File;
use Mail::SpamAssassin;
use Mail::SpamAssassin::NoMailAudit;
use File::Basename qw(basename);

# Global Sub Defs
sub version;
sub usage;
sub man;
sub _log($);
sub _err($);
sub startup;
sub puke($;$);
sub Interactive;
sub Install;
sub Startup;

# App-Specific Sub Defs
#sub signal_handler;
sub loadConfig($);
sub startSA;
sub reloadSA;
sub loadListener;
sub checkMail($);
sub stop;

# Signal Trapping
my $time_to_die = 0;
#sub signal_handler {
#	$SIG{BREAK} = $SIG{QUIT} = $SIG{INT} = $SIG{TERM} = $SIG{HUP} = \&signal_handler;
#$SIG{INT} = \&signal_handler;
#	$time_to_die = 1;
#}
#$SIG{BREAK} = $SIG{QUIT} = $SIG{INT} = $SIG{TERM} = $SIG{HUP} = \&signal_handler;
#$SIG{INT} = \&signal_handler;

# Handle Interactive/Service Modes
unless (defined &ContinueRun) {
	*ContinueRun      = sub { $quiet = 1; return 1 };
	*RunningAsService = sub { $quiet = 1; return 0 };
	Interactive();
}

# ----- Global Sub Defs

# Remove Service
sub Remove {
	$removing = 1;
	Install();
	stop;
}

# Help
sub Help { usage }

# Interactive Mode
sub Interactive {
	Install();
	Startup();
}

# Install
sub Install {

	# Global Option Defaults

	# App-Specific Option Defaults
	our ($quiet, $config, %ini, $spamTest, $siteRules, $defRules, $logConnects, $logClientNames, $mailRoot, $debug, $showBanner, $rewrite, $logGMT, $removing);
	our $maxCheckSize = 0;
	our $localhost = 'localhost';
	our $port = '7941';

	our %optionMappings = ('log' => \$log, 'help' => \$help, 'man' => \$man, 'version' => \$version, 'quiet' => \$quiet,
		'config' => \$config, 'stop' => \$stop);
	our @options = ("log=s", "help|?", "man", "version", "quiet!",
		"config=s", "stop");
	GetOptions(\%optionMappings, @options) || usage;
	version if $version;
	usage if $help;
	man if $man;

	# Catch Missing/Invalid Parameter Failures
	my $cwd = getcwd();
	$config = "$cwd/sad.ini" if ($config eq '' && -e "$cwd/sad.ini");
	usage if (! -e $config);

	%Config = (
		ServiceName => 'sad',
		DisplayName => 'SpamAssassin Daemon',
		Parameters  => "-config $config",
		Description => "SpamAssassin Daemon",
	);

	stop if $stop;

}

# Startup
sub Startup {

	Getopt::Long::GetOptions('config=s' => \$config);
	loadConfig($config);

	startup;

	while(ContinueRun() && !($time_to_die)) {
		startSA;
		loadListener;
	}

	_log "$awp v$ver shutting down.\n";
	puke(0);

}

# Show Syntax & Usage
sub usage {
	print <<EOF;
\n$awp v$ver\n$cpy\n\n$awp {options}

  -config        Configuration File

  -stop          Stop Service
  -install       Install Service
  -install auto  Install Service (Auto Startup)
  -remove        Remove Service

  -help | ?      Show This Help Text
  -man           Display Documentation
  -version       Show Version
EOF
	puke(0);
}

# Display Documentation
sub man { if (open(MAN,"$awp.txt")) { print <MAN>; close(MAN); } else { _err "Documentation not found." } $quiet = 1; puke(1); }

# Show Version
sub version { print $ver; exit(0); }

# Logging
sub _log($) {
	if ($log) {
		my $logfile = "$log/$awp\_" . strftime("%Y%m%d", localtime(time())) . '.log';
		open(LOGFILE, ">>$logfile") or die "ERROR:  Could not open $logfile: $!";
		if ($logGMT) {
			print LOGFILE strftime("%m/%d/%Y %I:%M:%S %p", gmtime(time())), " @_"
		} else {
			print LOGFILE strftime("%m/%d/%Y %I:%M:%S %p", localtime(time())), " @_"
		}
		close(LOGFILE)
	} else {
		print STDERR "@_"
	}
}
sub _err($) { print STDERR "ERROR:  @_" }

# Startup
sub startup {
	print "\n$awp v$ver\n$cpy\n\n" unless $quiet;
}

# Shutdown
sub puke($;$) {
	my $status = $_[0];
	my $message = $_[1];
	_err $message if $message;
	exit $status;
}

# ----- App-Specific Sub Defs

# Stop
sub stop {
	loadConfig($config);
	$client = IO::Socket::INET->new(Proto => "tcp", PeerAddr => $localhost, PeerPort => $port);
	if ($client) {
		$client->autoflush(1);
		print $client "SHUTDOWN\r\n";
		print <$client> unless $removing;
		close $client;
		_log "Received ShutDown Command.\n";
	} else {
		print "can't connect to port $port on $localhost: $!" unless $removing;
	}
	puke(0) unless $removing;
}

# Load Config
sub loadConfig($) {
	my ($config) = $_[0];
	tie %ini, 'Config::IniFiles', ( -file => "$config" );
	$localhost = $ini{'sad'}{'HostName'};
	$port = $ini{'sad'}{'Port'};
	$debug = $ini{'sad'}{'Debug'};
	$log = $ini{'sad'}{'LogDir'};
	$defRules = $ini{'SpamAssassin'}{'DefRules'};
	$siteRules = $ini{'SpamAssassin'}{'SiteRules'};
	$mailRoot = $ini{'sad'}{'MailRoot'};
	$logGMT = $ini{'sad'}{'LogGMT'};
	$logConnects = $ini{'sad'}{'LogConnects'};
	$logClientNames = $ini{'sad'}{'LogClientNames'};
	$showBanner = $ini{'sad'}{'ShowBanner'};
	$rewrite = $ini{'sad'}{'Rewrite'};
	$maxCheckSize = $ini{'sad'}{'MaxCheckSize'};
	for ($mailRoot, $defRules, $siteRules, $log) { s,\\,/,g; }
}

# Load Listener
sub loadListener {

	my ($endPoint, $client, $client_addr, $client_port, $client_ip, $client_ipnum, $client_host, $clientName, $buf, $commands, $cmd, $original);

	# Create Socket, Bind & Listen...
	my $sad = new IO::Socket::INET(
		LocalHost => $localhost,
		LocalPort => $port,
		Proto => getprotobyname('tcp'),
		Listen => 25,
		Reuse => 1
	) or die "io-socket failure: $!";
	my $select = new IO::Select();
	$select->add($sad);

#	my $local_host = gethostbyaddr($localhost, AF_INET);
	_log "$awp v$ver started on $localhost:$port\n";

	while (ContinueRun(0.05) && !($time_to_die)) {
		my @ready = $select->can_read(0.05);
		_log '@ready = \'' . @ready . "'\n" if $debug;

		foreach $endPoint (@ready) {
			_log '$endPoint = \'' . $endPoint . "'\n" if $debug;

			if ($endPoint == $sad) {
				($client, $client_addr) = $sad->accept();
				$select->add($client) if $client;
				($client_port, $client_ip) = sockaddr_in($client_addr);
				if ($logClientNames) {
					$client_host = gethostbyaddr($client_ip, AF_INET);
					$client_ipnum = inet_ntoa($client_ip);
					$clientName = "[$client_port] $client_host [$client_ipnum]";
				} else {
					$clientName = "[$client_port]";
				}
				_log "$clientName Connected\n" if $logConnects;
			}
			else {
				print $endPoint ":: $awp v$ver $cpy\r\nReady.  Send command now.\r\n" if $showBanner;
				$commands = <$endPoint>;
				if (defined $commands) {
					chomp($commands);
					chop($commands);
					($cmd, $original) = split(/ /, $commands);
					if ($cmd) {
						my ($saResults);
						if ($cmd eq 'PING') {
							$saResults = 'PONG';
						} elsif ($cmd eq 'CHECK') {
							if ($original) {
								$saResults = checkMail($original);
							} else {
								$saResults = 'Bad input - CHECK requires filename.';
							}
						} elsif ($cmd eq 'VERSION') {
							$saResults = "$awp v$ver";
#						} elsif ($cmd eq 'RELOAD') {
#							loadConfig($config);
#							reloadSA;
#							$saResults = 'CONFIG RELOADED';
						} elsif ($cmd eq 'SHUTDOWN') {
							$time_to_die = 1;
							$saResults = 'SHUTTING DOWN';
						} else {
							$saResults = "Unrecognized Command: $cmd";
						}
						if (!($saResults eq '')) {
							_log "$clientName \"$commands\" \"$saResults\"\n";
							print $endPoint "$saResults\r\n";
						} else {
							_log "$clientName \"$commands\" \"ERROR - NO RESULTS RETURNED\"\n";
							print $endPoint "ERROR - NO RESULTS RETURNED\r\n";
						}
					}
					else {
						_log "$clientName Bad input received\n";
						print $endPoint "Bad input received.\r\n";
					}
					$select->remove($endPoint);
					close($endPoint);
					_log "$clientName Disconnected\n" if $logConnects;
				} else {
					$select->remove($endPoint);
					close($endPoint);
				}
			}
		}
	}
}

# Instantiate SpamAssassin
sub startSA {
#	if (defined $spamTest) {
#		_log "UNDEF\n";
#		$spamTest = { };
#		undef $spamTest;
#		foreach (keys $spamTest) {
#			delete($spamTest{$_}) if ($spamTest{$_});
#		}
#	}
	$spamTest = Mail::SpamAssassin->new({
		rules_filename => $defRules,
		site_rules_filename => $siteRules,
		dont_copy_prefs => 1,
		local_tests_only => 1,
		debug => $debug,
	}) or die "Failed to create SpamAssassin object: $!";
}

# Reload SpamAssassin Config
# This doesn't work.
sub reloadSA {
	print "PRE-RELOAD\n";
	delete $spamTest->{conf};
	delete $spamTest->{debug};
	delete $spamTest->{dont_copy_prefs};
	delete $spamTest->{encapsulated_content_description};
	delete $spamTest->{local_tests_only};
	delete $spamTest->{locker};
	delete $spamTest->{PREFIX};
	delete $spamTest->{rules_filename};
	delete $spamTest->{save_pattern_hits};
	delete $spamTest->{site_rules_filename};
	delete $spamTest->{username};
	$spamTest = { };
	undef $spamTest;
	startSA;
	print "POST-RELOAD\n";
}

# Check Mail
sub checkMail($) {
	my ($original) = $_[0];

	# Handle MailRoot
	for ($original) { s,\\,/,g; }
	if (defined $mailRoot && $mailRoot ne '') {
		$original = "$mailRoot/" . basename($original);
	}

	# Exist Quick Check
	return "0.0;$!" unless (-e $original && -s $original > 0);

	# Size Quick Check
	return "0.0;Skipped due to MaxCheckSize" unless ($maxCheckSize > 0 && -s $original <= $maxCheckSize);

	# Read Email
	my $checkFile = new IO::File "< $original";
	return "0.0;$!" unless defined $checkFile;
	my @msglines = (<$checkFile>);
	$checkFile->close;

	# SA Check & Report
	my $testMail = Mail::SpamAssassin::NoMailAudit->new (data => \@msglines);
	my $status = $spamTest->check($testMail);
	my $statusMsg = $status->get_hits . ';' . $status->get_names_of_tests_hit;
	if ($rewrite) { $status->rewrite_mail (); }
	$status->finish();

	# Write New Email
	if ($rewrite) {
		my $newFile = new IO::File "> $original";
		return "0.0;Can't create rewritten mail file: $!" unless defined $newFile;
		print $newFile $testMail->header(), "\n", join ('', @{$testMail->body()});
		$newFile->close;
	}

	return $statusMsg;
}

1;
