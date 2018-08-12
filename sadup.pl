=for PDK_OPTS
   --exe sadup.exe --shared private --force --clean --verbose --freestanding --nologo --icon "d:/adminware/artwork/aw.ico"
   --add=Getopt::Long;Config::IniFiles;LWP::Simple;Net::SMTP;Win32::Service
   --info "CompanyName      = adminware, llc;
           FileDescription  = sadup - Updater for SpamAssassin Daemon for Win32;
           Copyright        = Copyright © 2004-2005 adminware, llc.  All rights reserved.;
           LegalCopyright   = Copyright © 2004-2005 adminware, llc.  All rights reserved.;
           LegalTrademarks  = adminware is a trademark of adminware, llc.  SpamAssassin is a trademark of Apache Software Foundation;
           SupportURL       = http://adminware.com/sad/;
           InternalName     = sadup;
           OriginalFilename = sadup;
           ProductName      = sadup;
           Language         = English;
           FileVersion      = 0.110.291.1;
           ProductVersion   = 0.110.291.1"
   sadup.pl
=cut

package PerlSvc;
our %Config = (ServiceName => 'sadup');

our $awp = 'sadup';
our $ver = '0.110.291.1';
our $cpy = 'Copyright © 2004-2005 adminware, llc.  All rights reserved.';

use strict;
#use warnings;
use Getopt::Long;
use vars qw($awp $ver $cpy $log $help $man $version $quiet $config %ini $siteRules %rules $reload $checkInterval $logGMT $time_to_die $serverIdentity $notifyAdmin $notifyAddress $smtpServer $localhost $port $client);

# App-Specific Modules
use Config::IniFiles;
use Cwd qw(getcwd);
use POSIX qw(strftime);
use Win32::API;
#use IO::Socket::INET;
use LWP::Simple qw(mirror is_success);
use Net::SMTP;
use Win32::Service;

# Check for iSE Enabled
Win32::API->Import("iSESupport", "int iSEInit()") || die "\nAborting!  iSESupport.dll not found.\n";
die "\niSE not enabled.  Please contact ODS Support for more information.\n" if (iSEInit());

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
sub signal_handler;
sub loadConfig($);
sub updateRuleSetDefs;
sub updateRules;
sub sendNotice($);
sub sendReload;
sub checkService;

# Signal Trapping
my $time_to_die = 0;
sub signal_handler {
	$SIG{BREAK} = $SIG{QUIT} = $SIG{INT} = $SIG{TERM} = $SIG{HUP} = \&signal_handler;
	$time_to_die = 1;
}
$SIG{BREAK} = $SIG{QUIT} = $SIG{INT} = $SIG{TERM} = $SIG{HUP} = \&signal_handler;

# Handle Interactive/Service Modes
unless (defined &ContinueRun) {
	*ContinueRun      = sub { $quiet = 1; return 1 };
	*RunningAsService = sub { $quiet = 1; return 0 };
	Interactive();
}

# ----- Global Sub Defs

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
	our ($config, %ini, $siteRules, %rules, $reload, $checkInterval, $cwd, $logGMT, $serverIdentity, $notifyAdmin, $notifyAddress, $smtpServer, $localhost, $port, $client);

	our %optionMappings = ('log' => \$log, 'help' => \$help, 'man' => \$man, 'version' => \$version, 'quiet' => \$quiet,
		'config' => \$config);
	our @options = ("log=s", "help|?", "man", "version", "quiet!",
		"config=s");
	GetOptions(\%optionMappings, @options) || usage;
	version if $version;
	usage if $help;
	man if $man;

	# Catch Missing/Invalid Parameter Failures
	my $cwd = getcwd();
	$config = "$cwd/sad.ini" if ($config eq '' && -e "$cwd/sad.ini");
	usage if (! -e $config);

	%Config = (
		ServiceName => 'sadup',
		DisplayName => 'SpamAssassin Daemon Updater',
		Parameters  => "-config $config",
		Description => "SpamAssassin Daemon Updater",
	);

}

# Startup
sub Startup {

	Getopt::Long::GetOptions('config=s' => \$config);
	loadConfig($config);

	startup;

	while(ContinueRun() && !($time_to_die)) {
		updateRules;
	}

	puke(0);

}

# Show Syntax & Usage
sub usage {
	print <<EOF;
\n$awp v$ver\n$cpy\n\n$awp {options}

  -config        Configuration File

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

# Load Config
sub loadConfig($) {
	my ($config) = $_[0];
	tie %ini, 'Config::IniFiles', ( -file => "$config" );
	$log = $ini{'sadup'}{'LogDir'};
	$siteRules = $ini{'SpamAssassin'}{'SiteRules'};
	$reload = $ini{'sadup'}{'Reload'};
	$checkInterval = $ini{'sadup'}{'CheckInterval'};
	$logGMT = $ini{'sadup'}{'LogGMT'};
	$serverIdentity = $ini{'sadup'}{'ServerIdentity'};
	$notifyAdmin = $ini{'sadup'}{'NotifyAdmin'};
	$notifyAddress = $ini{'sadup'}{'NotifyAddress'};
	$smtpServer = $ini{'sadup'}{'SMTPServer'};
	$localhost = $ini{'sad'}{'HostName'};
	$port = $ini{'sad'}{'Port'};
	for ($siteRules, $log) { s,\\,/,g; }
	checkService;
}

# Get RuleSets Definition Updates
sub updateRuleSetDefs {
}

# Get Updates
sub updateRules {
	while(ContinueRun() && !($time_to_die)) {

		# Reload Config
		loadConfig($config);

		my ($updateText);

		# Check Stable Rules Existence
		%rules = %{$ini{'CustomRulesStable'}};
		foreach my $ruleset (sort(keys(%rules))) {
			my $url = $rules{$ruleset};
			if (! -e "$siteRules/$ruleset") {
				print "Stable RuleSet: $ruleset -- ";
				my $rc = mirror($url, "$siteRules/$ruleset");
				if (is_success($rc)) {
					my $size = -s "$siteRules/$ruleset";
					print "DOWNLOADED\n";
					_log "Downloaded Stable RuleSet: $ruleset ($size bytes)\n";
					$updateText .= "Downloaded Stable RuleSet: $ruleset ($size bytes)\n";
				} else {
					print "ERROR\n";
				}
			} else {
				print "Stable RuleSet: $ruleset -- OKAY\n";
			}
		}

		# Update Active Rules
		%rules = %{$ini{'CustomRulesActive'}};
		foreach my $ruleset (sort(keys(%rules))) {
			my $url = $rules{$ruleset};
			print "Active RuleSet: $ruleset -- ";
			my ($size1);
			if (-e "$siteRules/$ruleset") { $size1 = -s "$siteRules/$ruleset"; $size1 = "$size1 -> " } else { $size1 = '' }
			my $rc = mirror($url, "$siteRules/$ruleset");
			if (is_success($rc)) {
				my $size2 = -s "$siteRules/$ruleset";
				print "UPDATED\n";
				_log "Updated RuleSet: $ruleset ($size1$size2 bytes)\n";
				$updateText .= "Updated RuleSet: $ruleset ($size1$size2 bytes)\n";
			} else {
				print "OKAY\n";
			}
		}

		_log "Update check complete.\n";

		# Notify Admin of Update(s)
		sendNotice($updateText) if ($notifyAdmin && !($updateText eq ''));

		# Send Reload Command
		sendReload unless $updateText eq '' || !($reload);

		# Wait for next update time...
		for (my $i = 0; $i <= 3600 * $checkInterval && ContinueRun() && !($time_to_die); $i++) { sleep(1) }

	}
}

# Send Email
sub sendNotice($) {
	my ($updateText) = $_[0];
	my ($serverName);
	if ($serverIdentity) { $serverName = " on $serverIdentity" }
	my $smtp = new Net::SMTP($smtpServer, Hello => "$notifyAddress");
	$smtp->mail($notifyAddress);
	$smtp->to($notifyAddress);
	$smtp->data();
	$smtp->datasend("To: $notifyAddress\n");
	$smtp->datasend("From: $notifyAddress\n");
	$smtp->datasend("Subject: SpamAssassin RuleSets Updated$serverName\n\n");
	$smtp->datasend("$updateText\n");
	$smtp->dataend();
	$smtp->quit;
}

# Send Reload Config
sub sendReload {
	my %status;
	Win32::Service::GetStatus('', 'sad', \%status);
	if ($status{CurrentState} != 1) {
		my $restarted = Win32::Service::StopService('', 'sad');
		if ($restarted) {
			_log "sad stopped.\n";
		} else {
			_log "Couldn't stop sad!\n";
		}
		sleep(3);
	}
	sleep(3);
	checkService;
#	$client = IO::Socket::INET->new(Proto => "tcp", PeerAddr => $localhost, PeerPort => $port);
#	if ($client) {
#		$client->autoflush(1);
#		print $client "SHUTDOWN\r\n";
#		print <$client>;
#		close $client;
#		_log "Sent SHUTDOWN to sad.\n";
#		sleep(2);
#		checkService;
#	} else {
#		_log "Couldn't establish connection to sad.  Attempting to restart.\n";
#		checkService;
#	}
}

# Check sad Service
sub checkService {
	my $restarted = Win32::Service::StartService('', 'sad');
	sleep(3);
	my %status;
	Win32::Service::GetStatus('', 'sad', \%status);
	if ($status{CurrentState} == 1) {
		my $restarted = Win32::Service::StartService('', 'sad');
		if ($restarted) {
			_log "sad restarted.\n";
		} else {
			_log "Couldn't start sad!\n";
		}
	}
}

1;
