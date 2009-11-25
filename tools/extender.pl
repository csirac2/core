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

no warnings 'redefine';

my $noconfirm       = 0;
my $downloadOK      = 0;
my $alreadyUnpacked = 0;
my $reuseOK         = 0;
my $inactive        = 0;
my $nocpan          = 0;
my $running_from_configure;
my $session;
my %available;
my $lwp;
my @archTypes = ( '.tgz', '.tar.gz', '.zip' );
my $installationRoot;
my $MODULE;
my $PACKAGES_URL;
my $MANIFEST;

sub _inform {
    if ($running_from_configure) {
        print "<div class='configureInfo'>",@_,"</div>\n";
    } else {
        print @_,"\n";
    }
}

sub _warn {
    if ($running_from_configure) {
        print '<div class="foswikiAlert configureWarn">',
          '<span><strong>Warning:</strong>',
            join( " ", @_ ),
              '</span></div>';
    } else {
        print "*WARNING* ",@_,"\n";
    }
}

sub _shout {
    if ($running_from_configure) {
        print '<div class="foswikiAlert configureError">',
          '<span><strong>Error:</strong>',
            join( " ", @_ ),
              '</span></div>';
    } else {
        print "### ERROR ### ",@_,"\n";
    }
}

sub _stop {
    _shout @_;
    die @_;
}

# Check if we were invoked from configure
# by looking at the call stack
my $i = 0;
while ( my $caller = caller( ++$i ) ) {
    if ( $caller =~ /^Foswiki::Configure::UIs::EXTEND$/ ) {
        $running_from_configure = 1;
        $noconfirm = 1;
        last;
    }
}

$installationRoot = Cwd::getcwd();

# getcwd is often a simple `pwd` thus it's tainted, untaint it
$installationRoot =~ /^(.*)$/;
$installationRoot = $1;

my $check_perl_module = sub {
    my $module = shift;
    
    if ( $module =~ /^CPAN/ ) {

        # Check how we were invoked as CPAN shouldn't
        # be loaded from configure
        if ($running_from_configure) {
            return $available{$module} = 0;
        }
    }
    if ( eval "use $module (); 1" ) {
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

# See if we can make a Foswiki. If we can, then we can save topic
# and attachment histories. Key off Foswiki::Merge because it is
# fairly new and fairly unique.
unless ( &$check_perl_module('Foswiki::Merge') ) {
    _stop("Can't find Foswiki: $@");
}

eval "use Foswiki ()";

_stop("Can't load Foswiki: $@") if $@;

# We have to get the admin user, as a guest user may be blocked.
my $user = $Foswiki::cfg{AdminUserLogin};
$session = new Foswiki($user);
chdir($installationRoot);

if ( &$check_perl_module('LWP') ) {
    $lwp = new LWP::UserAgent();
    $lwp->agent("PluginsInstaller");
    $lwp->env_proxy();
}
&$check_perl_module('CPAN');

# Can't do this until we have setlib.cfg
require Foswiki::Configure::Dependency;

sub remap {
    my $file = shift;

    if ( $Foswiki::cfg{SystemWebName} ne 'System' ) {
        $file =~ s#^data/System/#data/$Foswiki::cfg{SystemWebName}/#;
        $file =~ s#^pub/System/#pub/$Foswiki::cfg{SystemWebName}/#;
    }

    if ( $Foswiki::cfg{TrashWebName} ne 'Trash' ) {
        $file =~ s#^data/Trash/#data/$Foswiki::cfg{TrashWebName}/#;
        $file =~ s#^pub/Trash/#pub/$Foswiki::cfg{TrashWebName}/#;
    }

    if ( $Foswiki::cfg{UsersWebName} ne 'Main' ) {
        $file =~ s#^data/Main/#data/$Foswiki::cfg{UsersWebName}/#;
        $file =~ s#^pub/Main/#pub/$Foswiki::cfg{UsersWebName}/#;
    }

    if ( $Foswiki::cfg{UsersWebName} ne 'Users' ) {
        $file =~ s#^data/Users/#data/$Foswiki::cfg{UsersWebName}/#;
        $file =~ s#^pub/Users/#pub/$Foswiki::cfg{UsersWebName}/#;
    }

    # Canonical symbol mappings
    foreach my $w qw( SystemWebName TrashWebName UsersWebName ) {
        if ( defined $Foswiki::cfg{$w} ) {
            $file =~ s#^data/$w/#data/$Foswiki::cfg{$w}/#;
            $file =~ s#^pub/$w/#pub/$Foswiki::cfg{$w}/#;
        }
    }
    foreach my $t qw( NotifyTopicName HomeTopicName WebPrefsTopicName
      MimeTypesFileName ) {
        if ( defined $Foswiki::cfg{$t} )
        {
            $file =~
              s#^data/(.*)/$t\.txt(,v)?#data/$1/$Foswiki::cfg{$t}.txt$2/#;
            $file =~ s#^pub/(.*)/$t/([^/]*)$#pub/$1/$Foswiki::cfg{$t}/$2/#;
        }
      } return $file;
}

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

    if ( $dep->{type} eq 'cpan' && $available{CPAN} && !$nocpan ) {
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
                    if (!$running_from_configure) {
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

# install a package by running the installer
sub installPackage {
    my ($module) = @_;

    my $script = getInstaller($module);
    if ( $script && -e $script ) {
        my $cmd = "perl $script";
        $cmd .= ' -a' if $noconfirm;
        $cmd .= ' -nocpan' if $nocpan;
        $cmd .= ' -d' if $downloadOK;
        $cmd .= ' -r' if $reuseOK;
        $cmd .= ' -n' if $inactive;
        $cmd .= ' install';
        local $| = 0;

        # Fork the installation of the downloaded package.
        my $pid = fork();
        if ($pid) {
            wait();
            if ($?) {
                _shout STDERR "Installation of $module failed: $?";
                return 0;
            }
        }
        else {
            exec($cmd);
        }
    }
    else {
        _warn <<HERE;
I cannot locate an installer for $module.
$module may not have been designed to be installed with this installer.
HERE
        if (!$running_from_configure) {
            _warn <<HERE;
I might be able to download and unpack a simple archive, but you will
have to satisfy the dependencies and finish the install of it yourself,
as per the instructions for $module.
HERE
            my $ans = ask("Would you like me to try to get an archive of $module?");
            return 0 unless ($ans);
            my $arch = getArchive($module);
            unless ($arch) {
                print STDERR <<HERE;
Cannot locate an archive for $module; installation failed.
HERE
                return 0;
            }

            # Unpack the archive in place. Don't bother trying to
            # look for a MANIFEST or run the installer script - it
            # was probably packaged by an amateur.
            unpackArchive( $arch, $installationRoot );
        }
        return 0;
    }

    return 1;
}

=pod

---++ StaticMethod unpackArchive($archive [,$dir] )
Unpack an archive. The unpacking method is determined from the file
extension e.g. .zip, .tgz. .tar, etc. If $dir is not given, unpack
to a temporary directory, the name of which is returned.

=cut

sub unpackArchive {
    my ( $name, $dir ) = @_;

    $dir ||= File::Temp::tempdir( CLEANUP => 1 );
    chdir($dir);
    unless ( $name =~ /\.zip/i && unzip($name)
        || $name =~ /(\.tar\.gz|\.tgz|\.tar)/ && untar($name) )
    {
        $dir = undef;
        _shout "Failed to unpack archive $name";
    }
    chdir($installationRoot);

    return $dir;
}

sub unzip {
    my $archive = shift;

    if ( eval { require Archive::Zip } ) {
        my $zip = Archive::Zip->new();
        my $err = $zip->read($archive);
        if ($err) {
            _shout "Could not open zip file $archive (" . $err;
            return 0;
        }

        my @members = $zip->members();
        foreach my $member (@members) {
            my $file   = $member->fileName();
            my $target = $file;
            my $err    = $zip->extractMember( $file, $target );
            if ($err) {
                _shout "Failed to extract '$file' from zip file ",
                  $zip, ". Archive may be corrupt.";
                return 0;
            }
            else {
                _inform "    $target";
            }
        }
    }
    else {
        if (!$running_from_configure) {
            _warn
              "Archive::Zip is not installed; trying unzip on the command line";
        }
        print `unzip $archive`;
        if ($?) {
            _warn "unzip failed: $?\n";
            return 0;
        }
    }

    return 1;
}

sub untar {
    my $archive = shift;

    my $compressed = ( $archive =~ /z$/i ) ? 'z' : '';

    if ( eval { require Archive::Tar } ) {
        my $tar = Archive::Tar->new();
        my $numberOfFiles = $tar->read( $archive, $compressed );
        unless ( $numberOfFiles > 0 ) {
            _shout "Could not open tar file $archive ("
              . $tar->error();
            return 0;
        }

        my @members = $tar->list_files();
        foreach my $file (@members) {
            my $target = $file;

            my $ok = $tar->extract_file( $file, $target );
            unless ($ok) {
                _shout 'Failed to extract ', $file, ' from tar file ',
                  $tar, ". Archive may be corrupt.";
                return 0;
            }
            else {
                _inform "    $target";
            }
        }
    }
    else {
        if (!$running_from_configure) {
           _warn "Archive::Tar is not installed; "
                ."trying tar on the command-line";
        }
        for my $tarBin ( qw( tar gtar ) ) {
            _warn "Trying $tarBin on the command-line\n";
            system $tarBin, "xvf$compressed", $archive and return 1;
            if ($?) {
                print STDERR "$tarBin failed: $?\n";
            }
        }
        return 0;
    }

    return 1;
}

# Check in.
sub checkin {
    my ( $web, $topic, $file ) = @_;

    return 0 unless ($session);

    my $err = 1;

    if ($file) {
        my $origfile =
          $Foswiki::cfg{PubDir} . '/' . $web . '/' . $topic . '/' . $file;
        _inform "Add attachment $origfile";
        return 1 if ($inactive);
        print <<DONE;
##########################################################
Adding file: $file to installation ....
(attaching it to $web.$topic)
DONE

        # Need copy of file to upload it, use temporary location
        # Use non object version of File::Temp for Perl 5.6.1 compatibility
        my @stats    = stat $origfile;
        my $fileSize = $stats[7];
        my $fileDate = $stats[9];

        # make sure it's readable and writable by the current user
        chmod( ( $stats[2] & 07777 ) | 0600, $origfile );

        my ( $tmp, $tmpfilename ) = File::Temp::tempfile( unlink => 1 );
        if (File::Copy::copy( $origfile, $tmpfilename )) {
            eval {
                Foswiki::Func::saveAttachment(
                    $web, $topic, $file,
                    {
                        comment  => 'Saved by install script',
                        file     => $tmpfilename,
                        filesize => $fileSize,
                        filedate => $fileDate
                       }
                   );
            };
            $err = $@;
        } else {
            $err = "$origfile could not be copied to tmp dir ($tmpfilename): $!";
        }
        _shout $err if $err;
    }
    else {
        _inform "Add topic $web.$topic";
        return 1 if ($inactive);
        _inform <<DONE;
##########################################################
Adding topic: $web.$topic to installation ....
DONE

        # read the topic to recover meta-data
        eval {
            my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );
            Foswiki::Func::saveTopic( $web, $topic, $meta, $text,
                { comment => 'Saved by install script' } );
        };
        $err = $@;
    }
    return ( !$err );
}

sub _uninstall {
    my $file;
    my @dead;
    foreach $file ( keys %$MANIFEST ) {
        if ( -e $file ) {
            push( @dead, remap($file) );
        }
    }
    unless ( $#dead > 1 ) {
        _warn "No part of $MODULE is installed";
        return 0;
    }
    _warn "To uninstall $MODULE, the following files will be deleted:";
    if ($running_from_configure) {
        _inform "<ul><li>" . join( "</li><li>", @dead )."</li></ul>";
    } else {
        _inform "\t" . join( "\n\t", @dead );
    }
    return 1 if $inactive;
    my $reply = ask("Are you SURE you want to uninstall $MODULE?");
    if ($reply) {
        if ( defined &Foswiki::preuninstall ) {
            Foswiki::preuninstall();
        }
        elsif ( defined &TWiki::preuninstall ) {
            TWiki::preuninstall();
        }
        foreach $file ( keys %$MANIFEST ) {
            if ( -e $file ) {
                unlink($file);
            }
        }
        if ( defined &Foswiki::postuninstall ) {
            Foswiki::postuninstall();
        }
        elsif ( defined &TWiki::postuninstall ) {
            TWiki::postuninstall();
        }
        _inform "$MODULE uninstalled";
    }
    return 1;
}

# 1 Check dependencies
# 2 Transfer files from temporary unpack area to the target installation
# 3 Check in any files with existing ,vs on disc
# 4 Perform post-install
sub _emplace {
    my $source = shift;

    # For each file in the MANIFEST, move the file into the installation,
    # set the permissions, and check if it is a data or pub file. If it is,
    # then check it in.
    my @ci_topic;         # topics to checkin
    my @ci_attachment;    # topics to checkin
    my $file;
    foreach $file ( keys %$MANIFEST ) {
        my $source = "$source/$file";
        my $target = remap($file);
        _inform "Install $target, permissions $MANIFEST->{$file}->{perms}";
        unless ($inactive) {
            if ( -e $target ) {

              # Save current permissions, remove write protect for Windows sake,
              # Back up the file and then restore the original permissions
                my $mode = ( stat($file) )[2];
                chmod( oct(600), "$target" );
                chmod( oct(600), "$target.bak" ) if ( -e "$target.bak" );
                if ( File::Copy::move( $target, "$target.bak" ) ) {
                    chmod( $mode, "$target.bak" );
                }
                else {
                    _warn "Could not create $target.bak: $!";
                }
            }
            my @path = split( /[\/\\]+/, $target );
            pop(@path);
            if ( scalar(@path) ) {
                File::Path::mkpath( join( '/', @path ) );
            }
            if (!File::Copy::move( $source, $target )) {
                _shout "Failed to move $source to $target: $!";
            }
        }
        unless ($inactive) {
            chmod( oct( $MANIFEST->{$file}->{perms} ), $target )
              || _warn "Cannot set permissions on $target: $!";
        }
        if ( $MANIFEST->{$file}->{ci} ) {
            if ( $target =~ /^data\/(\w+)\/(\w+).txt$/ ) {
                push( @ci_topic, $target );
            }
            elsif ( $target =~ /^pub\/(\w+)\/(\w+)\/([^\/]+)$/ ) {
                push( @ci_attachment, $target );
            }
        }
    }
    my @bads;

    foreach $file (@ci_topic) {
        $file =~ /^data\/(.*)\/(\w+).txt$/;
        unless ( checkin( $1, $2, undef ) ) {
            push( @bads, $file );
        }
    }
    foreach $file (@ci_attachment) {
        $file =~ /^pub\/(.*)\/(\w+)\/([^\/]+)$/;
        unless ( checkin( $1, $2, $3 ) ) {
            push( @bads, $file );
        }
    }

    if ( scalar(@bads) ) {
        my $bl = "\t".join( "\n\t", @bads );
        _warn <<WHINE;
I cannot automatically update the local revision history for:
$bl

You can update the revision histories of these files by:
   1. Editing any topics and saving them without changing them,
   2. Uploading attachments to the same topics again.
Ignore this warning unless you have modified the files locally.
WHINE
    }
}

sub usage {
    _shout <<DONE;
Usage: ${MODULE}_installer -a -n -d -r -u -nocpan install
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
-nocpan means don't try to use CPAN to install missing libraries

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
        if ( defined &Foswiki::preinstall ) {
            Foswiki::preinstall();
        }
        elsif ( defined &TWiki::preinstall ) {
            TWiki::preinstall();
        }
        my $tmpdir = unpackArchive($archive);
        _inform "Archive unpacked";
        return 0 unless $tmpdir;
        return 0 unless _emplace($tmpdir);

        _inform "$MODULE installed";
        _warn ' with ', $unsatisfied . ' unsatisfied dependencies'
          if ($unsatisfied);
    }
    if ( defined &Foswiki::postinstall ) {
        Foswiki::postinstall();
    }
    elsif ( defined &TWiki::postinstall ) {
        TWiki::postinstall();
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
    print STDERR 'validatePerlModule removed '
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

    foreach my $row ( split( /\r?\n/, $data{MANIFEST} ) ) {
        my ( $file, $perms, $desc ) = split( ',', $row, 3 );
        $MANIFEST->{$file}->{ci} = ( $desc =~ /\(noci\)/ ? 0 : 1 );
        $MANIFEST->{$file}->{perms} = $perms;
    }

    my @deps;
    foreach my $row ( split( /\r?\n/, $data{DEPENDENCIES} ) ) {
        my ( $module, $condition, $trigger, $type, $desc ) =
          split( ',', $row, 5 );
        $module = Foswiki::Sandbox::untaint( $module, \&_validatePerlModule );
        if ( $trigger eq '1' ) {

            # ONLYIF is rare and dangerous
            push(
                @deps,
                new Foswiki::Configure::Dependency(
                    module      => $module,
                    type        => $type,
                    version     => $condition || 0,    # version condition
                    trigger     => 1,                  # ONLYIF condition
                    description => $desc
                )
            );
        }
        else {

            # There is a ONLYIF condition, warn user
            _warn 'The script uses an ONLYIF condition'
              . ' which is potentially insecure: "'
              . $trigger . '"';
            if ( $trigger =~ /^[a-zA-Z:\s<>0-9.()]*$/ ) {

                # It looks more or less safe
                push(
                    @deps,
                    new Foswiki::Configure::Dependency(
                        module      => $module,
                        type        => $type,
                        version     => $condition,    # version condition
                        trigger     => $1,            # ONLYIF condition
                        description => $desc
                    )
                );
            }
            else {
                _warn 'This ' . $trigger . ' condition does not look safe.';
                if ($running_from_configure) {
                    _shout <<DONE;
Disabling this as we were invoked from configure.
If you really want to install this module, do it from the command line.'
DONE
                }
                else {
                    my $reply = ask('Do you want to run it anyway?');
                    if ($reply) {
                        _inform 'OK...';
                        push(
                            @deps,
                            new Foswiki::Configure::Dependency(
                                module  => $module,
                                type    => $type,
                                version => $condition,    # version condition
                                trigger =>
                                  Foswiki::Sandbox::untaintUnchecked($1)
                                ,                         # ONLYIF condition
                                description => $desc
                            )
                        );
                    }
                }
            }
        }
    }

    unshift( @INC, 'lib' );

    my $n      = 0;
    my $action = 'install';
    while ( $n < scalar(@ARGV) ) {
        if ( $ARGV[$n] eq '-a' ) {
            $noconfirm = 1;
        }
        elsif ( $ARGV[$n] eq '-d' ) {
            $downloadOK = 1;
        }
        elsif ( $ARGV[$n] eq '-r' ) {
            $reuseOK = 1;
        }
        elsif ( $ARGV[$n] eq '-n' ) {
            $inactive = 1;
        }
        elsif ( $ARGV[$n] eq '-nocpan' ) {
            $nocpan = 1;
        }
        elsif ( $ARGV[$n] eq '-u' ) {
            $alreadyUnpacked = 1;
        }
        elsif ( $ARGV[$n] =~ m/(install|uninstall|manifest|dependencies)/ ) {
            $action = $1;
        }

# SMELL:   There really shouldn't be a null argument.  But installer breaks if it is there.
        elsif ( $ARGV[$n] eq '' ) {
            $n++;
            next;
        }
        else {
            usage();
            _shout 'Bad parameter ' . $ARGV[$n];
        }
        $n++;
    }

    if ( $action eq 'manifest' ) {
        foreach my $row ( split( /\r?\n/, $data{MANIFEST} ) ) {
            my ( $file, $perms, $desc ) = split( ',', $row, 3 );
            _inform "$file $perms $desc";
        }
        exit 0;
    }

    if ( $action eq 'dependencies' ) {
        foreach my $dep (@deps) {
            if ( $dep->{trigger} && $dep->{trigger} != '1' ) {
                _inform "ONLYIF $dep->{trigger}";
            }
            _inform $dep->{module}, ', ',
              $dep->{version}, ', ',
                $dep->{type}, ', ',
                  $dep->{description};
        }
        exit 0;
    }

    if (!$running_from_configure) {
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
    }

    if ( $action eq 'install' ) {
        _install( \@deps, $rootModule );
    }
    elsif ( $action eq 'uninstall' ) {
        _uninstall();
    }
}

1;
