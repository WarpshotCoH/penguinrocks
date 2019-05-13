# Penguin on the Rocks
***Current version: v0.9.0***

A City of Heroes installer/patcher/launcher for the command line, written in Perl. *(Aka it works on Linux, so hallelujah.)*

This script was passed along to me by a third party, after checking it over and amending it for the public servers I've released it here.

## System requirements
 - Perl 5 *(I have no clue if it'll run with Perl 6 or not)*
 - Perl modules:
   - Digest::MD5
   - File::Copy and File::Path
   - Getopt::Long
   - XML::Simple
 - wget or curl

While this tool is primarily for Linux & other UNIX-likes, it should also work on the Windows command line with Perl installed (e.g. via [Strawberry Perl](http://strawberryperl.com/)).

## Installation and usage
Put the launcher into the same folder as a City of Heroes (issue 24) install - if you don't have one, the launcher will download it for you in the current directory. Run the script from there.

The launcher runs similarly to Tequila - it downloads a manifest (currently defaulting to the one used for Paragon Chat/Titan Icon), patches everything in it, and then launches CoH with Wine if you're on Linux, or natively on Windows.

Further instructions on setting up Wine can be found on [the community document](https://docs.google.com/document/d/1OQ68rHr_BbA9QoHEEx9atG-xZiMFKCiXZVDPQ1JvrKc/).

```
Usage: penguinrocks.pl [--patchonly|--launchonly] [--verify] [--silentlaunch] [--silent] [--manifest=<URL of update manifest>] [City of Heroes options].

--silentlaunch: Suppress all console output from City of Heroes.
        This may improve stability or give a slight increase in framerate.
        For most people, I expect it will do nothing.
--silent: Suppress all output except error messages.
--patchonly: Only patch the City of Heroes client, do not launch it.
--launchonly: Only launch the City of Heroes client, do not patch it.
--verify: Verify the checksums of the client files.
--manifest: Specify an alternate manifest location.
```
