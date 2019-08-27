#!/usr/bin/perl

# Penguin on the Rocks
# City of Heroes installer/patcher/launcher
#
# Copyright (c) 2011-2016 [redacted]
#               2019 Warpshot
# No Rights Reserved
#
# https://github.com/WarpshotCoH/penguinrocks

# Version history:
#	0.5: First version, based on City of Heroes launcher 0.8.5
#	0.6: Added support for using assorted text-mode browsers to display news.
#	     Only verify the client files if there's an update available.
#	     Added support for verifying/repairing installations.
#	     Added support for running under Windows.
#	0.6.1: Fixed a bug in handling files with only one download URL.
#	       Improved handling of interrupted updates.
#	0.7: Added support for alternate manifest file locations and the training room.
#	     Switched to using Getopt::Long for argument parsing.
#	     Added "--launchonly" option.
#	     Fixed a bug in handling manifests with only one "launch" option.
#	0.7.1: Changed the default manifest download location
#	0.8: Changed manifest handling and selection of the beta/live server.
#	     Modified GetFile to loop over a list of URLs rather than try just one and die if it doesn't work.
#	0.8.1: Added support for deleting files
#	0.8.2: Added user-agent
#	0.9.0: Amended for public servers (removed beta server option since one no longer exists)
#	       Disabled news function until a similar service comes online
#	0.9.1: Fixed "--manifest" argument that I broke while cleaning things
#	       Added "--profile" argument to choose what profile to launch

# Must be run from the City of Heroes directory.  Running from an empty directory
# will install a new copy of City of Heroes, which is probably not what you want.


use warnings;
use strict;
use English '-no_match_vars';
use XML::Simple;
use File::Copy;
use File::Path;
use Getopt::Long;

my $version = "0.9.1";
my $useragent = 'PenguinRocks/' . $version . ' (' . $OSNAME . ')';

my $silent = 0;
my $silent_launch = 0;
my $patchonly = 0;
my $launchonly = 0;
my $verify = 0;
my $manifest_file;
my $profile;

my $get_program;
my $md5_program;
my $web_program;

my @args;

my $parser = XML::Simple->new(ForceArray => ['file', 'url', 'launch'], KeyAttr => []);

# Verify that all needed programs are available, and set up basic patching environment
sub Configure
{
	my $missing_programs = 0;

	# Either wget or curl
	if(system('wget --version >/dev/null 2>&1') == 0)
	{
		print "Using wget for file transfers.\n" if(!$silent);
		$get_program = 'wget --user-agent="' . $useragent . '" -c -O ';
 	}
	elsif(system("curl --version >/dev/null 2>&1") == 0)
	{
		print "Using curl for file transfers.\n" if(!$silent);
		$get_program = 'curl -A "' . $useragent . '" -o ';
		# NOTE: Transfer resuming ("-C -") is not used because cURL returns an error code
		# if the complete file has already been downloaded.
	}
	elsif(eval{ require LWP::UserAgent })
	{
		print "Using LWP::UserAgent for file transfers.\n" if(!$silent);
		$get_program = '_INTERNAL';
	}
	else
	{
		print STDERR "This script requires wget, curl, or libwww-perl to be installed.\n";
		$missing_programs = 1;
	}

	#MD5
	if(eval{ require Digest::MD5 })
	{
		print "Using Digest::MD5 for MD5 checksums.\n" if(!$silent);
		$md5_program = '_INTERNAL';
	}
	else
	{
		print STDERR "This script requires Digest::MD5 to be installed.\n";
		$missing_programs = 1;
	}

	# Web browser
	# if(system('lynx -version >/dev/null 2>&1') == 0)
	# {
	# 	print "Using Lynx for webpage display.\n" if(!$silent);
	# 	$web_program = 'lynx -dump ';
	# }
	# elsif(system('links -version >/dev/null 2>&1') == 0)
	# {
	# 	print "Using Links for webpage display.\n" if(!$silent);
	# 	$web_program = 'links -dump -html-numbered-links 1 ';
	# }
	# elsif(system('elinks -version >/dev/null 2>&1') == 0)
	# {
	# 	print "Using Elinks for webpage display.\n" if(!$silent);
	# 	$web_program = 'elinks -dump 1 ';
	# }
	# elsif(system('w3m -version >/dev/null 2>&1') == 0)
	# {
	# 	print "Using w3m for webpage display.\n" if(!$silent);
	# 	$web_program = 'w3m -dump ';
	# }
	# else
	# {
	# 	print "Unable to find a text-mode web browser.  To view news updates, one of\n";
	# 	print "Lynx, Links, Elinks, or w3m must be installed.\n";
	# 	$web_program = undef;
	# }

	exit(1) if($missing_programs);

	# Set up patch temp directory
	mkdir '.patches' if(! -e '.patches');
	die "Unable to create directory '.patches'\n" if(! -e '.patches' or ! -d '.patches');

	# Clean out any residue from the previous run
	unlink('.patches/tempfile.bin') if(-e '.patches/tempfile.bin');

	print "\n";
}

# Parse the command line
sub ParseOptions
{
	my $help = 0;

	Getopt::Long::Configure('no_auto_abbrev', 'pass_through');
	GetOptions(
		'silentlaunch' => \$silent_launch,
		'silent' => \$silent,
		'updateonly|patchonly' => \$patchonly,
		'launchonly' => \$launchonly,
		'verify' => \$verify,
		'help' => \$help,
		'manifest=s' => \$manifest_file,
		'profile=i' => \$profile
	);

	$silent_launch = 1 if($silent);
	$patchonly = 0 if($patchonly and $launchonly);

	if($help)
	{
		print "Penguin on the Rocks\n";
		print "\n";
		print "Usage: penguinrocks.pl [--patchonly|--launchonly] [--verify] [--silentlaunch] [--silent] [--manifest=<URL of update manifest>] [City of Heroes options].\n";
		print "\n";
		print "--silentlaunch: Suppress all console output from City of Heroes.\n";
		print "\tThis may improve stability or give a slight increase in framerate.\n";
		print "\tFor most people, I expect it will do nothing.\n";
		print "--silent: Suppress all output except error messages.\n";
		print "--patchonly: Only patch the City of Heroes client, do not launch it.\n";
		print "--launchonly: Only launch the City of Heroes client, do not patch it.\n";
		print "--verify: Verify the checksums of the client files.\n";
		print "--manifest: Specify an alternate manifest location.\n";
		print "--profile: Choose what profile number to launch (see manifest for the order, starting from 0).\n";
		print "\n";
		print "Passing the City of Heroes option '-renderthread 0' may be required, as\n";
		print "multithreaded rendering tends not to work on Linux.\n";
		print "\n";
		print "Run this script from an existing installation directory, or\n";
		print "from an empty directory to install a new copy of City of Heroes.\n";
		print "\n";
		print "This script has not been extensively tested; use at your own risk.\n";
		print "\n";
		print "penguinrocks.pl version $version\n";
		print "Copyright (c) 2011-2016 [redacted], 2019 Warpshot.  No Rights Reserved.\n";

		exit;
	}

	$manifest_file = "http://patch.savecoh.com/manifest.xml" if(! $manifest_file);
	$profile = 0 if(! $profile);

	return @ARGV;
}

sub GetNews
{
	if(defined($web_program) and !$silent)
	{
		system("$web_program 'https://www.google.com/'");
		print "\n";
	}
}

sub GetFile
{
	my $urls = shift;
	my $target = shift;
	my $result;

	my $base_index = int(rand(scalar(@{$urls})));
	my $count = scalar(@{$urls});
	my $url;

	for(my $i = 0; $i < $count; $i++)
	{
		$url = @{$urls}[($base_index + $i) % $count];
		if($get_program eq '_INTERNAL')
		{
			my $ua = LWP::UserAgent->new(env_proxy => 1);
			$ua->agent($useragent);
			$ua->show_progress(1) if(!$silent);
			my $response = $ua->get($url, ':content_file' => $target);
			if($response->is_success())
			{
				$result = 0;
			}
			else
			{
				print $response->status_line(), "\n";
				$result = 1;
			}
		}
		else
		{
			if($silent)
			{
				$result = system("$get_program $target $url >/dev/null 2>&1");
			}
			else
			{
				$result = system("$get_program $target $url");
			}
		}
	}
	die "Unable to fetch file ${url}\n" if($result != 0);
}

sub GetManifest
{
	my $updates_available = 0;
	unlink('.patches/manifest-new.xml');
	die "Unable to remove old manifest-new.xml\n" if(-e '.patches/manifest-new.xml');
	GetFile([$manifest_file], '.patches/manifest-new.xml');
	if($verify or (! -e '.patches/manifest.xml') or (GetMD5('.patches/manifest.xml') ne GetMD5('.patches/manifest-new.xml')))
	{
	}
	else
	{
		unlink('.patches/manifest-new.xml');
	}
}

sub GetMD5
{
	my $file = shift;
	my $file_MD5;

	if(!defined($md5_program))
	{
		return 0;	# If we can't check, return failure.  The COH patching system depends on being able to compare MD5s.
	}
	elsif($md5_program eq '_INTERNAL')
	{
		open INFILE, '<', $file;
		binmode INFILE;
		my $ctx = Digest::MD5->new();
		$ctx->addfile(*INFILE);
		$file_MD5 = $ctx->hexdigest();
		close INFILE;
	}
	else
	{
		$file_MD5 = `$md5_program '$file'`;
		$file_MD5 =~ s/([0-9a-fA-F]*).*/${1}/;
		chomp $file_MD5;
	}

	return $file_MD5;
}

sub VerifyMD5
{
	my $file = shift;
	my $MD5 = shift;
	my $file_MD5 = GetMD5($file);

	return (lc($MD5) eq lc($file_MD5));
}

sub RepairCoh
{
	my $parsed_xml = $parser->XMLin('.patches/manifest-new.xml');

	foreach my $file (@{$parsed_xml->{filelist}->{file}})
	{
		print "Checking $file->{name}...\n";

		if($file->{size} == 0 and $file->{name} !~ /\.\./)
		{
			print "Removing $file->{name}\n" if(!$silent);
			unlink($file->{name});
		}
		elsif((! -e $file->{name}) or (!VerifyMD5($file->{name}, $file->{md5})))
		{
			GetFile($file->{url}, '.patches/tempfile.bin');
			VerifyMD5('.patches/tempfile.bin', $file->{md5}) || die "Downloaded file $file->{name} does not have correct MD5 checksum.\n";
			unlink($file->{name}) if(-e $file->{name});
			my ($target_dir) = $file->{name} =~ /^(.*\/)/;
			if(defined($target_dir) and (! -d "${target_dir}"))
			{
				File::Path::make_path("${target_dir}") || die "Unable to make directory ${target_dir}\n";
			}
			File::Copy::move('.patches/tempfile.bin', $file->{name}) || die "Failed to move file $file->{name}: $!\n";
		}
	}
	unlink('.patches/manifest.xml') if(-e '.patches/manifest.xml');
	die "Unable to remove old manifest.xml\n" if(-e '.patches/manifest.xml');
	File::Copy::copy('.patches/manifest-new.xml', '.patches/manifest.xml');
}

sub LaunchCoh
{
	my @args = @_;
	my $command;
	my $exe;
	my $params;

	my $parsed_xml = $parser->XMLin('.patches/manifest.xml');
	if($parsed_xml->{profiles}->{launch}->[$profile])
	{
		print "Launching profile #$profile ($parsed_xml->{profiles}->{launch}->[$profile]->{content})\n";
		$exe = $parsed_xml->{profiles}->{launch}->[$profile]->{exec};
		$params = $parsed_xml->{profiles}->{launch}->[$profile]->{params};
		$exe =~ s/\\/\//g;
	}
	else
	{
		die "Profile #$profile doesn't exist in the given manifest.\n";
	}

	if(-x "/opt/cxgames/bin/wine")
	{
		$command = "/opt/cxgames/bin/wine --cx-app ${exe} ${params} " . join(" ", @args);
	}
	elsif(-x "$ENV{HOME}/cxgames/bin/wine")
	{
		$command = "~/cxgames/bin/wine --cx-app ${exe} ${params} " . join(" ", @args);
	}
	elsif($OSNAME eq 'MSWin32')
	{
		$command = "$exe " . join(" ", @args);
	}
	else
	{
		$command = "wine ${exe} ${params} " . join(" ", @args);
	}
	$command .= " >/dev/null 2>&1" if($silent_launch);
	exec($command);
}

@args = ParseOptions();
Configure();
# GetNews(); # Removed as the site is down.
if(!$launchonly)
{
	GetManifest();
	if(-e '.patches/manifest-new.xml')
	{
		RepairCoh();	# The COH patch system doesn't distinguish between a "repair", an "update", and an "install".
	}
	else
	{
		# sleep(5) if(!$silent);	# Give the user a (brief) chance to read the news
	}
}

if(!$patchonly)
{
	LaunchCoh(@args);
}
