# See bottom of file for license and copyright information

package Foswiki::Configure::Util;

use strict;

sub getScriptName {
    my @script = File::Spec->splitdir( $ENV{SCRIPT_NAME} || 'THISSCRIPT' );
    my $scriptName = pop(@script);
    $scriptName =~ s/.*[\/\\]//;    # Fix for Item3511, on Win XP
    return $scriptName;
}

# very basic tool
sub findFileOnPath {
    my $file = shift;

    $file =~ s(::)(/)g;

    foreach my $dir (@INC) {
        if ( -e "$dir/$file" ) {
            return "$dir/$file";
        }
    }
    return;
}

=begin TML

---++ StaticMethod mapTarget($root, $file )
Map a standard filename from the default paths to any alternate file
locations defined in $Foswiki::cfg.  Adjust for changes in directory
names and also Web names.   The following mapping is performed:

---+++ Web names

   * =SystemWebName=
   * =TrashWebname=
   * =UsersWebname=
   * =SandboxWebName= ( Future - see  Foswikitask:Item8744 )

---+++ Topic Names
   * =NotifyTopicName=
   * =HomeTopicName=
   * =WebPrefsTopicName= 

---+++ Directory locations
   * =DataDir=
   * =PubDir=
   * =WorkingDir=
   * =TemplateDir=
   * =ToolsDir=
   * =LocalesDir=

---+++ Other 
   * =ScriptSuffix=
   * =MimeTypesFileName=

---+++ NOT Handled
   * bin directory is assumed to be bin

=cut


sub mapTarget {
    my $root = shift;
    my $file = shift;
    # Workaround for Tasks.Item8744 feature proposal
    my $sandbox = $Foswiki::cfg{SandboxWebName} || 'Sandbox';

    foreach my $t qw( NotifyTopicName:WebNotify HomeTopicName:WebHome WebPrefsTopicName:WebPreferences
      ) {
        my ($val, $def) = split( ':', $t);
        if ( defined $Foswiki::cfg{$val} )
        {
            $file =~
              s#^data/(.*)/$def(\.txt(?:,v)?)$#data/$1/$Foswiki::cfg{$val}$2#;
            $file =~ s#^pub/(.*)/$def/([^/]*)$#pub/$1/$Foswiki::cfg{$val}/$2#;
        }
      } 

    if ( defined $Foswiki::cfg{MimeTypesFileName} && ($file eq 'data/mime.types') ) {
        $file =~ 
              s#^data/mime\.types$#$Foswiki::cfg{MimeTypesFileName}#;
        return $file;
        }

    if ( $sandbox ne 'Sandbox' ) {
        $file =~ s#^data/Sandbox/#data/$sandbox/#;
        $file =~ s#^pub/Sandbox/#pub/$sandbox/#;
    }

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
    #foreach my $w qw( SystemWebName TrashWebName UsersWebName SandboxWebName ) {  #Waiting for Item8744
    foreach my $w qw( SystemWebName TrashWebName UsersWebName ) {
        if ( defined $Foswiki::cfg{$w} ) {
            $file =~ s#^data/$w/#data/$Foswiki::cfg{$w}/#;
            $file =~ s#^pub/$w/#pub/$Foswiki::cfg{$w}/#;
        }
    }
    $file =~ s#^data/Sandbox/#data/$sandbox/#;
    $file =~ s#^pub/Sandbox/#pub/$sandbox/#;


    if ( $file =~ s#^data/#$Foswiki::cfg{DataDir}/# ) {
    }
    elsif ( $file =~ s#^pub/#$Foswiki::cfg{PubDir}/# ) {
    }
    elsif ( $file =~ s#^templates/#$Foswiki::cfg{TemplateDir}/# ) {
    }
    elsif ( $file =~ s#^tools/#$Foswiki::cfg{ToolsDir}/# ) {
    }
    elsif ( $file =~ s#^locale/#$Foswiki::cfg{LocalesDir}/# ) {
    }
    elsif ( $file =~ s#^(bin/\w+)$#$root$1$Foswiki::cfg{ScriptSuffix}# )
    {

        #This makes a couple of bad assumptions
        #1. that the twiki's bin dir _is_ called bin
        #2. that any file going into there _is_ a script - making installing the
        #   .htaccess file via this machanism impossible
        #3. that softlinks are not in use (same issue below)
    }
    else {
        $file = File::Spec->catfile( $root, $file );
    }
    return $file;
}

=begin TML

---++ StaticMethod getMappedWebTopic( $file )
Extract a mapped Web,TopicName from the default path from a topic in the manifest.
(Works for topics, not attachments)

Returns ($web, $topic) 

---+++ Web names

   * =SystemWebName=
   * =TrashWebname=
   * =UsersWebname=
   * =SandboxWebName= ( Future - see  Foswikitask:Item8744 )

---+++ Topic Names
   * =NotifyTopicName=
   * =HomeTopicName=
   * =WebPrefsTopicName= 

=cut


sub getMappedWebTopic {
    my $file = shift;

    # Workaround for Tasks.Item8744 feature proposal
    my $sandbox = $Foswiki::cfg{SandboxWebName} || 'Sandbox';

    foreach my $t qw( NotifyTopicName:WebNotify HomeTopicName:WebHome WebPrefsTopicName:WebPreferences
      ) {
        my ($val, $def) = split( ':', $t);
        if ( defined $Foswiki::cfg{$val} )
        {
            $file =~
              s#^data/(.*)/$def(\.txt(?:,v)?)$#data/$1/$Foswiki::cfg{$val}$2#;
        }
      } 

    if ( $sandbox ne 'Sandbox' ) {
        $file =~ s#^data/Sandbox/#$sandbox/#;
    }

    if ( $Foswiki::cfg{SystemWebName} ne 'System' ) {
        $file =~ s#^data/System/#$Foswiki::cfg{SystemWebName}/#;
    }

    if ( $Foswiki::cfg{TrashWebName} ne 'Trash' ) {
        $file =~ s#^data/Trash/#$Foswiki::cfg{TrashWebName}/#;
    }

    if ( $Foswiki::cfg{UsersWebName} ne 'Main' ) {
        $file =~ s#^data/Main/#$Foswiki::cfg{UsersWebName}/#;
    }

    if ( $Foswiki::cfg{UsersWebName} ne 'Users' ) {
        $file =~ s#^data/Users/#$Foswiki::cfg{UsersWebName}/#;
    }

    # Canonical symbol mappings
    #foreach my $w qw( SystemWebName TrashWebName UsersWebName SandboxWebName ) {  #Waiting for Item8744
    foreach my $w qw( SystemWebName TrashWebName UsersWebName ) {
        if ( defined $Foswiki::cfg{$w} ) {
            $file =~ s#^data/$w/#$Foswiki::cfg{$w}/#;
        }
    }
    $file =~ s#^data/Sandbox/#$sandbox/#;

    my ($tweb, $ttopic) = $file =~ /^(.*)\/(\w+).txt$/;


    return ($tweb, $ttopic);
}

=begin TML

---++ StaticMethod createArchive($name, $dir, $delete )
Create an archive of the passed directory. 
   * $name is the directory to be backed up _and_ the filename of the archive to be created.  $name will be given a suffix of the backup type - depends on what type of backup tools are installed.
   * $dir is the root directory of the backups - typically the working/configure/backup directory
   * $delete - set if the directory being backed up should be deleted after archive is created.

=cut

sub createArchive {
    my ( $name, $dir, $delete, $test ) = @_;
    eval {use File::Path qw(rmtree)};

    my $file = undef;
    my $results = '';
    my $warn = '';
  
    my $here = Cwd::getcwd();
    $here =~ /(.*)/; $here = $1;    # untaint current dir name

    return ( undef, "Directory $dir/$name does not exist \n") unless (-e "$dir/$name" && -d "$dir/$name");
    
    chdir("$dir/$name");

    if (!defined $test || (defined $test && $test eq 'tar')) {
        $results .= `tar -czvf "../$name.tgz" .`;

        if ($results && ! $@) { 
            $file = "$dir/$name.tgz";
        }
    }

    unless ($results) {
        $warn .= "tar command failed $!, trying zip \n"; 

        if (!defined $test || (defined $test && $test eq 'zip')) {
            $results .= `zip -r "../$name.zip" .`; 
        
            if ($results && ! $@) {
                $file = "$dir/$name.zip";
            }  
        }


        unless ($results) {
            $warn .= "zip failed $!, trying perl routines \n"; 

            if (!defined $test || (defined $test && $test eq 'Ptar')) {
                my @flist = Foswiki::Configure::Util::listDir('.', 1);
                $results = _tar ( "../$name.tgz", \@flist );

                if ($results) {
                    $file = "$dir/$name.tgz";
                }
            }

            unless ($results) {
                $warn .= "Perl Archive::Tar failed - trying zip \n"; 

                if (!defined $test || (defined $test && $test eq 'Pzip')) {
                    my @flist = Foswiki::Configure::Util::listDir('.', 1);
                    $results = _zip ( "../$name.zip", \@flist );

                    if ($results) {
                        $file = "$dir/$name.zip";
                    } else {
                        $warn .= "Perl Archive::Zip failed - Backup directory remains \n"; 
                    }
                }
            }
        }
    }



    chdir($here);

    return (undef, $warn) unless ($results);

    rmtree("$dir/$name") if ($delete);
    return ($file, $results);

}

sub _zip {
    my $archive = shift;
    my $files = shift;
    my $err;

    eval 'use Archive::Zip ( )';
    unless ($@) {
        my $zip = Archive::Zip->new();
        unless ($zip) {
            return 0;
        }

        # Note:  Archive::Zip addTree fails with taint errors.  
        # Workaround was to add each file individually
        foreach my $f ( @$files ) {
            $zip->addFile( $f );
        }
        $err = $zip->writeToFileNamed("$archive");
        return join("\n",$zip->memberNames()) unless ($err);
    }

    return 0;
}

sub _tar {
    my $archive = shift;
    my $files = shift;

    eval 'use Archive::Tar ()';
    unless ($@) {
        my $tgz = Archive::Tar->new();
        return 0 unless ($tgz);
        $tgz->add_files( @$files );
        $tgz->write( "$archive", 7) ;
        return join("\n", $tgz->list_files());
    }
    return 0;
}

=begin TML

---++ StaticMethod unpackArchive($archive [,$dir] )
Unpack an archive. The unpacking method is determined from the file
extension e.g. .zip, .tgz. .tar, etc. If $dir is not given, unpack
to a temporary directory, the name of which is returned.

=cut

sub unpackArchive {
    my ( $name, $dir ) = @_;

    $dir ||= File::Temp::tempdir( CLEANUP => 1 );
    my $here = Cwd::getcwd();
    $here =~ /(.*)/; $here = $1;    # untaint current dir name
    chdir($dir);
    my $error = "Failed to unpack archive $name\n";

    if ($name =~ m/\.zip$/i) {
        $error = _unzip($name);
    } else {
        if ( $name =~ m/(\.tar\.gz|\.tgz|\.tar)$/i ) {
            $error = _untar($name); 
        }
    }
    $dir = undef if ($error);
    chdir($here);

    return ($dir, $error);
}

sub _unzip {
    my $archive = shift;

    eval 'use Archive::Zip';
    unless ($@) {
        my $zip = Archive::Zip->new($archive);
        unless ($zip) {
            return "Could not open zip file $archive\n";
        }

        my @members = $zip->members();
        foreach my $member (@members) {
            my $file = $member->fileName();
            $file =~ /(.*)/; $file = $1;    #yes, we must untaint
            my $target = $file;
            my $err = $zip->extractMember( $file, $target );
            if ($err) {
                return "Failed to extract '$file' from zip file ",
                  $zip, ". Archive may be corrupt.\n";
            }
        }
    }
    else {
        my $out = `unzip -n $archive`;

        # On certain older versions of perl / unzip it seems the unzip results
        # in an illegal seek error. But running the same command again often
        # goes well. Seems like the 2nd pass works because the subdirectories
        # are then created. A hack but it seems to work.
        if ($?) {
            `unzip -n $archive`;
            if ($?) {
                return "unzip failed: $!\n";
            }
        }
    }

    return;
}

sub _untar {
    my $archive = shift;


    my $compressed = ( $archive =~ /z$/i ) ? 'z' : '';

    eval 'use Archive::Tar ()';
    unless ($@) {
        my $tar = Archive::Tar->new( $archive, $compressed );
        unless ($tar) {
            return "Could not open tar file $archive\n";
        }

        my @members = $tar->list_files();
        foreach my $file (@members) {
            my $err = $tar->extract($file);
            unless ($err) {
                return 'Failed to extract ', $file, ' from tar file ',
                  $tar, ". Archive may be corrupt.\n";
            }
        }
    }
    else {
        `tar xvf$compressed $archive`;
        if ($?) {
            return "tar failed: $? -  $!\n";
        }
    }

    return;
}

=begin TML

---++ StaticMethod listDir($dir, [$dflag], [$path] )
Recursively list the files in directory $dir. Optional $dflag can be set to 1
to cause the list to exclude the directory names from the list. 

If $path is used internally for the recursive directory list. It is
appended to the Directory.  The list of files in @names is relative to the
$dir directory.   Subroutine called recursively for each subdirectory
encountered.

=cut

# Recursively list a directory
sub listDir {
    my ( $dir, $dflag,  $path ) = @_;
    $path ||= '';
    $dflag ||= '';
    $dir .= '/' unless $dir =~ /\/$/;
    my $d;
    my @names = ();
    if ( opendir( $d, "$dir$path" ) ) {
        foreach my $f ( grep { !/^\.*$/ } readdir $d ) {

            # Someone might upload a package that contains
            # a filename which, when passed to File::Copy, does something
            # evil. Check and untaint the filenames here.
            # SMELL: potential problem with unicode chars in file names? (yes)
            if ( $f =~ /^([-\w.,]+)$/ ) {
                $f = $1;
                if ( -d "$dir$path/$f" ) {
                    push( @names, "$path$f/" ) unless ($dflag);
                    push( @names, listDir( $dir, $dflag,  "$path$f/" ) );
                }
                else {
                    push( @names, "$path$f" );
                }
            }
            else {
                print
"WARNING: skipping possibly unsafe file (not able to show it for the same reason :( )<br />\n";
            }
        }
        closedir($d);
    }
    return @names;
}

=begin TML

---++ StaticMethod getPerlLocation( )
This routine will read in the first line of the bin/configure 
script and recover the location of the perl interpreter.

=cut

sub getPerlLocation {

    local $/ = "\n"; 
    open (my $fh, '<', "$Foswiki::cfg{ScriptDir}/configure$Foswiki::cfg{ScriptSuffix}") 
        || return '' ;
    my $shBang  = <$fh>;
    chomp $shBang;
    $shBang =~ s/^#\!\s*(.*?)\s?(:?\s-.*)?$/$1/;
    $shBang =~ s/\s+$//;
    close ($fh);
    return $shBang;

}
=begin TML

---++ StaticMethod rewriteShbang($file, $newShbang )
This routine will rewrite the Shbang line of the target script
with the specified script name.

=cut

sub rewriteShbang {
    my $file = shift;
    my $newShbang = shift;

    return unless (-f $file );

    local $/ = undef;
    open(my $fh, '<', $file) || return "Rewrite shbang failed:  $!";
    my $contents = <$fh>;
    close $fh;

    # Note: space inserted after #! - needed on some flavors of Unix
    if( $contents =~ s/^#!\s*\S+/#! $newShbang/s ) {
        my $mode = (stat($file))[2];
        $file =~ /(.*)/; $file = $1;   
        chmod( oct(600), "$file");
        open(my $fh, '>', $file) || return "Rewrite shbang failed:  $!";
        print $fh  $contents;
        close $fh;
        $mode =~ /(.*)/; $mode = $1;   
        chmod( $mode, "$file");
    } 
}



1;
__DATA__
#
# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008-2009 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
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
