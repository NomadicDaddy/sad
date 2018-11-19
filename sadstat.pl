=for PDK_OPTS
   --exe sadstat.exe --force --verbose --freestanding --nologo --icon "d:/adminware/artwork/aw.ico"
   --add=Config::IniFiles;IO::Socket::INET;Net::SMTP
   --info "CompanyName      = adminware, llc;
           FileDescription  = sadstat - Status Monitor for SpamAssassin Daemon for Win32;
           Copyright        = Copyright � 2004-2005 adminware, llc;
           LegalCopyright   = Copyright � 2004-2005 adminware, llc;
           LegalTrademarks  = adminware is a trademark of adminware, llc.  SpamAssassin is a trademark of Apache Software Foundation;
           SupportURL       = http://adminware.com/sad/;
           InternalName     = sadstat;
           OriginalFilename = sadstat;
           ProductName      = sadstat;
           Language         = English;
           FileVersion      = 0.01.101.1;
           ProductVersion   = 0.01.101.1"
   sadstat.pl
=cut

our $awp = 'sadstat';
our $ver = '0.01.101.1';
our $cpy = 'Copyright � 2004-2005 adminware, llc';

use strict;
#use warnings;
use PerlTray;
use vars qw($awp $ver $cpy $config %ini $notifyAdmin $notifyAddress $smtpServer $localhost $port $client);

# App-Specific Modules
use Config::IniFiles;
use Cwd qw(getcwd);
use IO::Socket::INET;
use Net::SMTP;

# Global Sub Defs
sub PopupMenu;

# App-Specific Sub Defs
sub loadConfig($);
sub sendNotice($);
sub sendReload;

# Global Option Defaults

# App-Specific Option Defaults
my ($config, %ini, $notifyAdmin, $notifyAddress, $smtpServer, $localhost, $port, $client);

# ----- Global Sub Defs

# ----- App-Specific Sub Defs

sub PopupMenu {
	return [

		["*adminware", "Execute 'http://adminware.com'"],
		["MessageBox", sub { MessageBox("This is a $_!") }],

		["--------"],

		["Start sad"],
		["Stop sad"],
		["Start sadup"],
		["Stop sadup"],

		["--------"],

#		["o Fast   :50",  \$freq],
#		["x Medium :100"],
#		["o Slow   :200"],
#		["o Fast",   '$freq =  50', $freq==50],
#		["o Medium", '$freq = 100', $freq==100],
#		["o Slow",   '$freq = 200', $freq==200],

		["--------"],

		["_ Unchecked", ""],
		["v Checked", undef, 1],
#		["v Checked", \$check],

		["--------"],
		["  E&xit", "exit"],
	];
}

# Load Config
sub loadConfig($) {
	my ($config) = $_[0];
	tie %ini, 'Config::IniFiles', ( -file => "$config" );
	$notifyAdmin = $ini{'sadup'}{'NotifyAdmin'};
	$notifyAddress = $ini{'sadup'}{'NotifyAddress'};
	$smtpServer = $ini{'sadup'}{'SMTPServer'};
	$localhost = $ini{'sad'}{'HostName'};
	$port = $ini{'sad'}{'Port'};
}

#sub show_balloon {
#	Balloon("This is the message", "Balloon Title", "Error", 15);
#}

sub ToolTip { localtime }

sub Timer {
    SetTimer(0);
    Balloon("Timer triggered Message", "The Balloon", "Info", 5);
}
