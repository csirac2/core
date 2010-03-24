# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 1999-2009 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root of
# this distribution. NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.
#
# Author: Crawford Currie http://wikiring.com
#
# This module contains the functions used by the extensions installer.
# It is not treated as a "standard" module because it has radically
# different environment requirements (i.e. as few as possible)
#
# It is invoked from the individual installer scripts shipped with
# extensions, and should not be run directly.
#
package Foswiki::Extender;
use strict;
use warnings;

use Cwd;
use File::Temp;
use File::Copy;
use File::Path;
use Getopt::Std;

no warnings 'redefine';

my $noconfirm       = 0;
my $downloadOK      = 0;
my $alreadyUnpacked = 0;
my $reuseOK         = 0;
my $inactive        = 0;
my $nocpan          = 0;
my $action          = 'install';  # Default target is install
my $session;
my $thispkg;         # Package object for THIS module
my %available;
my $lwp;
my @archTypes = ( '.tgz', '.tar.gz', '.zip' );
my $installationRoot;
my $MODULE;
my $PACKAGES_URL;
my $MANIFEST;

sub _inform {
        print @_,"\n";
}

sub _warn {
        print "*WARNING* ",@_,"\n";
}

sub _shout {
        print "### ERROR ### ",@_,"\n";
}

sub _stop {
    _shout @_;
    die @_;
}

# processParameters
my %opts;
getopts('acdnoru', \%opts);
$noconfirm = $opts{a};
$nocpan = $opts{c};
$downloadOK = $opts{d};
$reuseOK = $opts{r};
$inactive = $opts{n};
$alreadyUnpacked = $opts{u};
if( @ARGV > 1 ) {
    usage();
    _stop( 'Too many parameters: ' . join(" ", @ARGV) );
}
$action = $ARGV[0] if $ARGV[0];

$installationRoot = Cwd::getcwd();

# getcwd is often a simple `pwd` thus it's tainted, untaint it
$installationRoot =~ /^(.*)$/;
$installationRoot = $1;

my $check_perl_module = sub {
    my $module = shift;
    
    if ( eval "require $module" ) {
        $available{$module} = 1;
    }
    else {
        _warn("$module is not available on this server,"
                . " some installer functions have been disabled");
        $available{$module} = 0;
    }
    return $available{$module};
};

unless ( -d 'lib' && -d 'bin' && -e 'bin/setlib.cfg' ) {
    _stop('This installer must be run from the root directory'
            . ' of a Foswiki installation');
}

# read setlib.cfg
chdir('bin');
require 'setlib.cfg';
chdir($installationRoot);

# See if we can make a Foswiki. If we can, then we can save topic
# and attachment histories. Key off Foswiki::Merge because it is
# fairly new and fairly unique.
unless ( &$check_perl_module('Foswiki::Merge') ) {
    _stop("Can't find Foswiki: $@");
}

# Use the CLI engine
$Foswiki::cfg{Engine} = 'Foswiki::Engine::CLI';
unless ( eval { require Foswiki } ) {
    _stop("Can't load Foswiki: $@");
}

# We have to get the admin user, as a guest user may be blocked.
my $user = $Foswiki::cfg{AdminUserLogin};
$session = new Foswiki($user);

if ( &$check_perl_module('LWP') ) {
    $lwp = new LWP::UserAgent();
    $lwp->agent("PluginsInstaller");
    $lwp->env_proxy();
}
&$check_perl_module('CPAN');

# Can't do this until we have setlib.cfg
require Foswiki::Configure::Dependency;
require Foswiki::Configure::Util;
require Foswiki::Configure::Package;


# Satisfy dependencies on modules, by checking:
# 1. If the module is a perl module, then:
#    1. If the module is loadable in the current environment
#    2. If the dependency has specified a version constraint, then
#       the module must have a top-level variable VERSION which satisfies
#       the constraint.
#       Note that all Foswiki modules are perl modules - even non-perl
#       distributions have a perl 'stub' module that carries the version info.
# 2. If the module is _not_ perl, then we can't check it.
sub satisfy {
    my $dep  = shift;
    my $trig = eval $dep->{trigger};

    return 1 unless ($trig);

    _inform "Checking dependency on $dep->{module}....";
    my ( $ok, $msg ) = $dep->check();

    if ($ok) {
        _inform $msg;
        return 1;
    }

    _warn <<DONE;
$MODULE depends on $dep->{type} package $dep->{module} $dep->{version}
which is described as "$dep->{description}"
But when I tried to find it I got this error:

$msg
DONE

    if ( $dep->{module} =~ m/^(Foswiki|TWiki)::(Contrib|Plugins)::(\w*)/ ) {
        my $type     = $1;
        my $pack     = $2;
        my $packname = $3;
        $packname .= $pack if ( $pack eq 'Contrib' && $packname !~ /Contrib$/ );
        $dep->{name} = $packname;
        if ( !$noconfirm || ( $noconfirm && $downloadOK ) ) {
            my $reply =
              ask(  'Would you like me to try to download '
                  . 'and install the latest version of '
                  . $packname
                  . ' from foswiki.org?' );
            return 0 unless $reply;
            return installPackage($packname);
        }
    }

    if ( $dep->{type} =~ m/cpan/i && $available{CPAN} && !$nocpan ) {
        _inform <<'DONE';
This module is available from the CPAN archive (http://www.cpan.org). You
can download and install it from here. The module will be installed
to wherever you configured CPAN to install to.
DONE
        my $reply =
          ask(  'Would you like me to try to download '
              . 'and install the latest version of '
              . $dep->{module}
              . ' from cpan.org?' );
        return 0 unless $reply;

        my $mod = CPAN::Shell->expand( 'Module', $dep->{module} );
        my $info = $mod->dslip_status();
        if ( $info->{D} eq 'S' ) {

            # Standard perl module!
            _shout <<DONE;
$dep->{module} is a standard perl module

I cannot install it without upgrading your version of perl, something
I'm not willing to do. Please either install the module manually (from
a package downloaded from cpan.org) or upgrade your perl to a version
that includes this module.
DONE
            return 0;
        }
        if ($noconfirm) {
            $CPAN::Config->{prerequisites_policy} = 'follow';
        }
        else {
            $CPAN::Config->{prerequisites_policy} = 'ask';
        }
        CPAN::install( $dep->{module} );
        ( $ok, $msg ) = $dep->check();
        return 1 if $ok;

        my $e = 'it';
        if ( $CPAN::Config->{makepl_arg} =~ /PREFIX=(\S+)/ ) {
            $e = $1;
        }
        _shout <<DONE;
I still can't find the module $dep->{module}

If you installed the module in a non-standard directory, make sure you
have followed the instructions in bin/setlib.cfg and added $e
to your \@INC path.

DONE
    }

    return 0;
}

=pod

---++ StaticMethod ask( $question ) -> $boolean
Ask a question.
Example: =if( ask( "Proceed?" )) { ... }=

=cut

sub ask {
    my $q = shift;
    my $reply;

    return 1 if $noconfirm;
    local $/ = "\n";

    $q .= '?' unless $q =~ /\?\s*$/;

    print $q. ' [y/n] ';
    while ( ( $reply = <STDIN> ) !~ /^[yn]/i ) {
        print "Please answer yes or no\n";
    }
    return ( $reply =~ /^y/i ) ? 1 : 0;
}

=pod

---++ StaticMethod prompt( $question, $default ) -> $string
Prompt for a string, using a default if return is pressed.
Example: =$dir = prompt("Directory")=;

=cut

sub prompt {
    my ( $q, $default ) = @_;
    my $reply = '';
    local $/ = "\n";
    while ( !$reply ) {
        print $q;
        print " ($default)" if defined $default;
        print ': ';
        $reply = <STDIN>;
        chomp($reply);
        $reply ||= $default;
    }
    return $reply;
}

# Try and find an installer or archive.
# Look in (1) the current directory (2) on the $TWIKI_PACKAGES path and
# (3) in the twikiplugins subdirectory (if there, to support developers)
# and finally (4) download from $PACKAGES_URL
sub getComponent {
    my ( $module, $types, $what ) = @_;
    my $f;

    # Look for the archive.
    require Config;
    if ( !$noconfirm || ( $noconfirm && $reuseOK ) ) {
        foreach my $dir (
            $installationRoot,
            $installationRoot . '/twikiplugins/' . $module,
            split( $Config::Config{path_sep}, $ENV{TWIKI_PACKAGES} || '' )
          )
        {
            foreach my $type (@$types) {    # .tgz preferred
                $f = $dir . '/' . $module . $type;
                if ( -e $f ) {
                    my @st      = stat($f);
                    my $credate = localtime( $st[9] );
                    print <<HERE;
$f exists on this machine; would you like me to use it?
It was created on $credate.
If not, I will try to download a new one.
HERE
                    if ( ask("Use existing $f?") ) {
                        print "Got a local $what from $f\n";
                        return $f;
                    }
                }
            }
        }
    }

    unless ($lwp) {
        _shout <<HERE;
Cannot find a local $what for $module, and LWP is not installed
so I can't download it. Please download it manually and re-run
this script.
HERE
        return;
    }

    my $url         = "$PACKAGES_URL/$module/$module";
    my $downloadDir = $installationRoot;

    if ( $ENV{TWIKI_PACKAGES} && -d $ENV{TWIKI_PACKAGES} ) {

        # see if we can write in $TWIKI_PACKAGES
        my $test = $ENV{TWIKI_PACKAGES} . '/' . $$;
        if ( open( F, '>', $test ) ) {
            close(F);
            unlink($test);
            $downloadDir = $ENV{TWIKI_PACKAGES};
        }
    }

    my $response;
    foreach my $type (@$types) {
        $f = $downloadDir . '/' . $module . $type;
        $response = $lwp->get( $url . $type,
            ':content_file' => $f );

        if ( $response->header( "Client-Warning" ) ) {
            _shout "Failed to download $module $what\n",
              "LWP complains about: ", $response->header( "Client-Warning" );
            return;
        }
    }

    unless ( $f && -s $f ) {
        _shout "Failed to download $module $what\n"
          . $response->status_line();
        return 0;
    }
    else {
        _inform "Downloaded $what from $PACKAGES_URL to $f";
    }

    return $f;
}

# Try and find an archive for the named module.
sub getArchive {
    my $module = shift;

    return getComponent( $module, \@archTypes, 'archive' );
}

# Try and find an installer for the named module.
sub getInstaller {
    my $module = shift;

    return getComponent( $module, ['_installer'], 'installer' );
}

sub _loadInstaller {
    $thispkg = new Foswiki::Configure::Package ("$installationRoot/", $MODULE, '', $session);
    my ($rslt, $err) = $thispkg->loadInstaller();

    _warn "$rslt" if ($rslt);
    _stop "$err" if ($err);
}


# install a package by running the installer
sub installPackage {
    my ($module) = @_;

    my $script = getInstaller($module);
    if ( $script && -e $script ) {
        my @cmd = Foswiki::Sandbox::untaintUnchecked( $^X );
        push @cmd, $script;
        push @cmd, '-a' if $noconfirm;
        push @cmd, '-d' if $downloadOK;
        push @cmd, '-r' if $reuseOK;
        push @cmd, '-n' if $inactive;
        push @cmd, '-c' if $nocpan;
        push @cmd, 'install';
        local $| = 0;

        # Fork the installation of the downloaded package.
        my $pid = fork();
        if ($pid) {
            wait();
            if ($?) {
                _shout "Installation of $module failed: $?";
                return 0;
            }
        }
        else {
            exec(@cmd);
        }
    }
    else {
        _warn <<HERE;
I cannot locate an installer for $module.
$module may not have been designed to be installed with this installer.
HERE
        _warn <<HERE;
I might be able to download and unpack a simple archive, but you will
have to satisfy the dependencies and finish the install of it yourself,
as per the instructions for $module.
HERE
        my $ans = ask("Would you like me to try to get an archive of $module?");
        return 0 unless ($ans);
        my $arch = getArchive($module);
        unless ($arch) {
            _shout <<HERE;
Cannot locate an archive for $module; installation failed.
HERE
            return 0;
        }

        # Unpack the archive in place. Don't bother trying to
        # look for a MANIFEST or run the installer script - it
        # was probably packaged by an amateur.
        unpackArchive( $arch, $installationRoot );
        return 0;
    }

    return 1;
}


sub _uninstall {
    my $file;
    my @dead;
    my $rslt = '';
    my $err = '';

    $rslt = $thispkg->createBackup();

    _inform "$rslt";
   
    @dead = $thispkg->uninstall('1') unless ($err);

    unless ( $#dead > 1 ) {
        _warn "No part of $MODULE is installed";
        return 0;
    }
    _warn "To uninstall $MODULE, the following files will be deleted:";
    _inform "\t" . join( "\n\t", @dead );

    return 1 if $inactive;
    my $reply = ask("Are you SURE you want to uninstall $MODULE?");
    if ($reply) {
   
        $thispkg->preuninstall() if (defined $thispkg->preinstall);

        @dead = $thispkg->uninstall() ;

        $thispkg->postuninstall() if (defined $thispkg->postuninstall);

        $thispkg->finish();
        undef $thispkg;

        _inform "$MODULE uninstalled";
    }
    return 1;
}


sub usage {
    _shout <<DONE;
Usage: ${MODULE}_installer -a -n -d -r -u -c install
       ${MODULE}_installer -a -n uninstall
       ${MODULE}_installer manifest
       ${MODULE}_installer dependencies

Operates on the directory tree below where it is run from,
so should be run from the top level of your Foswiki installation.

install will check dependencies and perform any required
post-install steps.

uninstall will remove all files that were installed for
$MODULE even if they have been locally modified.

-a means don't prompt for confirmation before resolving
   dependencies
-d means auto-download if -a (no effect if not -a)
-r means reuse packages on disc if -a (no effect if not -a)
-u means the archive has already been downloaded and unpacked
-n means don't write any files into my current install, just
   tell me what you would have done
-c means don't try to use CPAN to install missing libraries
-o means running from configure, so outputs HTML

manifest will generate a list of the files in the package on
standard output. The list is generated in the same format as
the MANIFEST files used by BuildContrib.

dependencies will generate a list of dependencies on standard
output. the list is generated in the same format as the
DEPENDENCIES files used by BuidContrib.

DONE
}

# 1 Check and satisfy dependencies
# 2 Check if there is already an install of this module, and seek
#   overwrite confirmation
# 3 Locate a suitable archive, download if necessary
# 4 Unpack the archive
# 5 Move files into the target tree
# 6 Clean up
sub _install {
    my ( $deps, $rootModule ) = @_;
    my $unsatisfied = 0;
    foreach my $dep (@$deps) {
        unless ( satisfy($dep) ) {
            $unsatisfied++;
        }
    }

    my $path = $MODULE;

    if ( $path !~ /^(Foswiki|TWiki)::/ ) {
        my $source = 'Foswiki';
        my $type   = 'Contrib';
        if ( $path =~ /Plugin$/ ) {
            $type = 'Plugins';
        }
        $path = $source . '::' . $type . '::' . $rootModule;
    }

    if ( eval "use $path; 1;" ) {

        # Module is already installed

        # XXX SMELL: Could be more user-friendly:
        # test that current version isn't newest
        my $moduleVersion = 0;
        {
            no strict 'refs';
            $moduleVersion = ${"${path}::VERSION"};

            # remove the SVN marker text from the version number, if it is there
            $moduleVersion =~ s/^\$Rev: (\d+) \$$/$1/;
        }

        if ($moduleVersion) {
            return 0
              unless ask(
                          "$MODULE version $moduleVersion is already installed."
                        . " Are you sure you want to re-install this module?"
              );
        }
    }

    if (!$alreadyUnpacked) {
        _inform "Fetching the archive for $path.";
        my $archive = getArchive($MODULE);

        unless ($archive) {
            _warn "Unable to locate suitable archive for install";
            return 0;
        }

        my ($tmpdir, $error) = Foswiki::Configure::Util::unpackArchive($archive);
        _inform "Archive unpacked - ";
        _warn $error if ($error);
        return 0 unless $tmpdir;
       
        my $rslt = '';
        my $err = '';

        $rslt = $thispkg->createBackup() ;
        _inform "$rslt";
        $rslt = '';

        $rslt = $thispkg->preinstall() if (defined $thispkg->preinstall);
        _inform "$rslt" if ($rslt);

        ($rslt, $err) = $thispkg->install($tmpdir);
        _inform "$rslt";
        $rslt = '';

        $rslt = $thispkg->postinstall() if (defined $thispkg->postinstall);
        _inform "$rslt" if ($rslt);

        $thispkg->finish();
        undef $thispkg;


        _inform "$MODULE installed";
        _warn " INSTALL FAILED with errors $err" if ($err);
        _warn ' with ', $unsatisfied . ' unsatisfied dependencies'
          if ($unsatisfied);
    }

    return ( $unsatisfied ? 0 : 1 );
}

# Invoked when the user installs a new extension using
# the configure script. It is used to ensure the perl module dependencies
# provided by the module are real module names, and not some random garbage
# which could be potentially insecure.
sub _validatePerlModule {
    my $module = shift;

    # Remove all non alpha-numeric caracters and :
    # Do not use \w as this is localized, and might be tainted
    my $replacements = $module =~ s/[^a-zA-Z:_0-9]//g;
    _warn 'validatePerlModule removed '
      . $replacements
      . ' characters, leading to '
      . $module . "\n"
      if $replacements;
    return $module;
}

sub install {
    $PACKAGES_URL = shift;
    $MODULE       = shift;
    my $rootModule = shift;
    push( @_, '' ) if ( scalar(@_) & 1 );
    my %data = @_;

    my @deps;

    unshift( @INC, 'lib' );

    _loadInstaller();

    if ( $action eq 'manifest' ) {
        _inform $thispkg->Manifest();
        exit 0;
    }

    if ( $action eq 'dependencies' ) {
        my ($installed, $missing,  @wiki, @cpan, @manual) = $thispkg->checkDependencies();

        _inform $installed;
        _inform $missing;

        exit 0;
    }

    _inform "\n${MODULE} Installer";
    _inform <<DONE;
This installer must be run from the root directory of your Foswiki
installation.
DONE
    unless ($noconfirm) {
        _inform <<DONE
    * The script will not do anything without asking you for
      confirmation first (unless you used -a).
DONE
        }
        _inform <<DONE;
    * You can abort the script at any point and re-run it later
    * If you answer 'no' to any questions you can always re-run
      the script again later
DONE

    if ( $action eq 'install' ) {
        my ($installed, $missing,  @wiki, @cpan, @manual) = $thispkg->checkDependencies();
        push @deps, @wiki;
        push @deps, @cpan;
        _install( \@deps, $rootModule );
    }
    elsif ( $action eq 'uninstall' ) {
        _uninstall();
    }
}

1;
