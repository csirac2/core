# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Store::VC::Store

Almost-complete implementation of =Foswiki::Store=. The methods
of this class implement the =Foswiki::Store= interface.

The store uses a "handler" class to handle all interactions with the
actual version control system (and via it with the actual file system).
A "handler" is created for each individual file in the file system, and
this handler then brokers all requests to open, read, write etc the file.
The handler object must implement the interface specified by
=Foswiki::Store::VC::Handler=.

The main additional responsibilities of _this_ class are to support storing
Foswiki meta-data in plain text files, and to ensure that the =Foswiki::Meta=
for a page is maintained in synchronisation with the files on disk.

All that is required to create a working store is to subclass this class
and override the 'new' method to specify the actual handler to use. See
Foswiki::Store::RcsWrap for an example subclass.

For readers who are familiar with Foswiki version 1.0, the functionality
in this class _previously_ resided in =Foswiki::Store=.

These methods are documented in the Foswiki:Store abstract base class

=cut

package Foswiki::Store::VC::Store;
use strict;
use warnings;

use Foswiki::Store ();
our @ISA = ('Foswiki::Store');

use Assert;
use Error qw( :try );

use Foswiki          ();
use Foswiki::Meta    ();
use Foswiki::Sandbox ();

BEGIN {

    # Do a dynamic 'use locale' for this module
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;
    $this->SUPER::finish();
    undef $this->{searchFn};
}

# SMELL: this module does not respect $Foswiki::inUnitTestMode; tests
# just sit on top of the store which is configured in the current LocalSite.
# Most of the time this is ok, as store listeners will be told that
# the store is in test mode, so caches should be unaffected. However
# it's very untidy, potentially risky, and causes grief when unit tests
# don't clean up after themselves.

# PACKAGE PRIVATE
# Get a handler for the given object in the store.
sub getHandler {

    #my ( $this, $web, $topic, $attachment ) = @_;
    ASSERT( 0, "Must be implemented by subclasses" ) if DEBUG;
}

sub readTopic {
    my ( $this, $topicObject, $version ) = @_;

    my ($gotRev, $isLatest) =  $this->askListeners($topicObject);

    if (defined($gotRev) and ($gotRev > 0)) {
        return ($gotRev, $isLatest) 
    }
    ASSERT(not $isLatest) if DEBUG;

    my $handler = $this->getHandler($topicObject);
    $isLatest = 0;

    # check that the requested revision actually exists
    if ( defined $version ) {
        if ( !$version || !$handler->revisionExists($version) ) {
            $version = $handler->getLatestRevisionID();
        }
    }

    (my $text, $isLatest) = $handler->getRevision($version);
    unless (defined $text) {
        ASSERT(not $isLatest) if DEBUG;
        return (undef, $isLatest) 
    }

    $text =~ s/\r//g;    # Remove carriage returns
    $topicObject->setEmbeddedStoreForm($text);

    $gotRev = $version;
    unless ( defined $gotRev ) {

        # First try the just-loaded text for the revision
        my $ri = $topicObject->get('TOPICINFO');
        if ( defined($ri) ) {

            # SMELL: this can end up overriding a correct rev no (the one
            # requested) with an incorrect one (the one in the TOPICINFO)
            $gotRev = $ri->{version};
        }
    }
    if ( !$gotRev ) {

        # No revision from any other source; must be latest
        $gotRev = $handler->getLatestRevisionID();
        ASSERT(defined $gotRev) if DEBUG;
    }

    # Add attachments that are new from reading the pub directory.
    # Only check the currently requested topic.
    if (   $Foswiki::cfg{RCS}{AutoAttachPubFiles}
        && $topicObject->isSessionTopic() )
    {
        my @knownAttachments = $topicObject->find('FILEATTACHMENT');
        my @attachmentsFoundInPub =
          $handler->synchroniseAttachmentsList( \@knownAttachments );
        my @validAttachmentsFound;
        foreach my $foundAttachment (@attachmentsFoundInPub) {

            # test if the attachment filename is valid without having to
            # be sanitized. If not, ignore it.
            my $validated = Foswiki::Sandbox::validateAttachmentName(
                $foundAttachment->{name} );
            unless ( defined $validated
                && $validated eq $foundAttachment->{name} )
            {

                print STDERR 'AutoAttachPubFiles ignoring '
                  . $foundAttachment->{name} . ' in '
                  . $topicObject->getPath()
                  . ' - not a valid Foswiki Attachment filename';
            }
            else {
                push @validAttachmentsFound, $foundAttachment;
                $this->tellListeners(verb=>'autoattach', newmeta=>$topicObject, newattachment=>$foundAttachment);
            }
        }

        $topicObject->putAll( 'FILEATTACHMENT', @validAttachmentsFound )
          if @validAttachmentsFound;
    }
    
    ASSERT(defined($gotRev)) if DEBUG;
    return ($gotRev, $isLatest);
}

sub moveAttachment {
    my ( $this, $oldTopicObject, $oldAttachment, $newTopicObject,
        $newAttachment, $cUID )
      = @_;

    my $handler = $this->getHandler( $oldTopicObject, $oldAttachment );
    if ( $handler->storedDataExists() ) {
        $handler->moveAttachment( $this, $newTopicObject->web,
            $newTopicObject->topic, $newAttachment );
        $this->tellListeners(verb=>'update', oldmeta=>$oldTopicObject, oldattachment=>$oldAttachment, newmeta=>$newTopicObject, newattachment=>$newAttachment);
        $handler->recordChange( $cUID, 0 );
    }
}

sub copyAttachment {
    my ( $this, $oldTopicObject, $oldAttachment, $newTopicObject,
        $newAttachment, $cUID )
      = @_;

    my $handler = $this->getHandler( $oldTopicObject, $oldAttachment );
    if ( $handler->storedDataExists() ) {
        $handler->copyAttachment( $this, $newTopicObject->web,
            $newTopicObject->topic, $newAttachment );
        $this->tellListeners(verb=>'insert', newmeta=>$newTopicObject, newattachment=>$newAttachment);
        $handler->recordChange( $cUID, 0 );
    }
}

sub attachmentExists {
    my ( $this, $topicObject, $att ) = @_;
    my $handler = $this->getHandler( $topicObject, $att );
    return $handler->storedDataExists();
}

sub moveTopic {
    my ( $this, $oldTopicObject, $newTopicObject, $cUID ) = @_;
    ASSERT($cUID) if DEBUG;

    my $handler = $this->getHandler( $oldTopicObject, '' );
    my $rev = $handler->getLatestRevisionID();

    $handler->moveTopic( $this, $newTopicObject->web, $newTopicObject->topic );

    $this->tellListeners(verb=>'update', oldmeta=>$oldTopicObject, newmeta=>$newTopicObject);

    if ( $newTopicObject->web ne $oldTopicObject->web ) {

        # Record that it was moved away
        $handler->recordChange( $cUID, $rev );
    }

    $handler = $this->getHandler( $newTopicObject, '' );
    $handler->recordChange( $cUID, $rev );
}

sub moveWeb {
    my ( $this, $oldWebObject, $newWebObject, $cUID ) = @_;
    ASSERT($cUID) if DEBUG;

    my $handler = $this->getHandler($oldWebObject);
    $handler->moveWeb( $newWebObject->web );

    $this->tellListeners(verb=>'update', oldmeta=>$oldWebObject, newmeta=>$newWebObject);

    # We have to log in the new web, otherwise we would re-create the dir with
    # a useless .changes. See Item9278
    $handler = $this->getHandler($newWebObject);
    $handler->recordChange( $cUID, 0, 'Moved from ' . $oldWebObject->web );
}

sub testAttachment {
    my ( $this, $topicObject, $attachment, $test ) = @_;
    my $handler = $this->getHandler( $topicObject, $attachment );
    return $handler->test($test);
}

sub openAttachment {
    my ( $this, $topicObject, $att, $mode, @opts ) = @_;

    my $handler = $this->getHandler( $topicObject, $att );
    return $handler->openStream( $mode, @opts );
}

sub getRevisionHistory {
    my ( $this, $topicObject, $attachment ) = @_;

    my $handler = $this->getHandler( $topicObject, $attachment );
    return $handler->getRevisionHistory();
}

sub getNextRevision {
    my ( $this, $topicObject ) = @_;
    my $handler = $this->getHandler($topicObject);
    return $handler->getNextRevisionID();
}

sub getRevisionDiff {
    my ( $this, $topicObject, $rev2, $contextLines ) = @_;
    ASSERT( defined($contextLines) ) if DEBUG;

    my $rcs = $this->getHandler($topicObject);
    return $rcs->revisionDiff( $topicObject->getLoadedRev(), $rev2,
        $contextLines );
}

sub getAttachmentVersionInfo {
    my ( $this, $topicObject, $rev, $attachment ) = @_;
    my $handler = $this->getHandler( $topicObject, $attachment );
    return $handler->getInfo( $rev || 0 );
}

sub getVersionInfo {
    my ( $this, $topicObject ) = @_;
    my $handler = $this->getHandler($topicObject);
    return $handler->getInfo( $topicObject->getLoadedRev() );
}

sub saveAttachment {
    my ( $this, $topicObject, $name, $stream, $cUID ) = @_;
    my $handler    = $this->getHandler( $topicObject, $name );
    my $currentRev = $handler->getLatestRevisionID();
    my $nextRev    = $currentRev + 1;
    my $verb = ($topicObject->hasAttachment($name)) ? 'update' : 'insert';
    $handler->addRevisionFromStream( $stream, 'save attachment', $cUID );
    $this->tellListeners(verb=>$verb, newmeta=>$topicObject, newattachment=>$name);
    $handler->recordChange( $cUID, $nextRev );
    return $nextRev;
}

sub saveTopic {
    my ( $this, $topicObject, $cUID, $options ) = @_;
    ASSERT( $topicObject->isa('Foswiki::Meta') ) if DEBUG;
    ASSERT($cUID) if DEBUG;

    my $handler = $this->getHandler($topicObject);

    my $verb = ($topicObject->existsInStore()) ? 'update' : 'insert';

    $handler->addRevisionFromText( $topicObject->getEmbeddedStoreForm(),
        'save topic', $cUID, $options->{forcedate} );

    # just in case they are not sequential
    my $nextRev = $handler->getLatestRevisionID();

    my $extra = $options->{minor} ? 'minor' : '';
    $handler->recordChange( $cUID, $nextRev, $extra );

    $this->tellListeners(verb=>$verb, newmeta=>$topicObject);

    return $nextRev;
}

sub repRev {
    my ( $this, $topicObject, $cUID, %options ) = @_;
    ASSERT( $topicObject->isa('Foswiki::Meta') ) if DEBUG;
    ASSERT($cUID) if DEBUG;

    my $info    = $topicObject->getRevisionInfo();
    my $handler = $this->getHandler($topicObject);
    $handler->replaceRevision( $topicObject->getEmbeddedStoreForm(),
        'reprev', $info->{author}, $info->{date} );
    my $rev = $handler->getLatestRevisionID();
    $handler->recordChange( $cUID, $rev, 'minor, reprev' );

    $this->tellListeners(verb=>'update', newmeta=>$topicObject);

    return $rev;
}

sub delRev {
    my ( $this, $topicObject, $cUID ) = @_;
    ASSERT( $topicObject->isa('Foswiki::Meta') ) if DEBUG;
    ASSERT($cUID) if DEBUG;

    my $handler = $this->getHandler($topicObject);
    my $rev     = $handler->getLatestRevisionID();
    if ( $rev <= 1 ) {
        throw Error::Simple( 'Cannot delete initial revision of '
              . $topicObject->web . '.'
              . $topicObject->topic );
    }
    $handler->deleteRevision();

    # restore last topic from repository
    $handler->restoreLatestRevision($cUID);

    # reload the topic object
    $topicObject->unload();
    $topicObject->loadVersion();

    $this->tellListeners(verb=>'update', newmeta=>$topicObject);

    $handler->recordChange( $cUID, $rev );

    return $rev;
}

sub atomicLockInfo {
    my ( $this, $topicObject ) = @_;
    my $handler = $this->getHandler($topicObject);
    return $handler->isLocked();
}

# It would be nice to use flock to do this, but the API is unreliable
# (doesn't work on all platforms)
sub atomicLock {
    my ( $this, $topicObject, $cUID ) = @_;
    my $handler = $this->getHandler($topicObject);
    $handler->setLock( 1, $cUID );
}

sub atomicUnlock {
    my ( $this, $topicObject, $cUID ) = @_;

    my $handler = $this->getHandler($topicObject);
    $handler->setLock( 0, $cUID );
}

# A web _has_ to have a preferences topic to be a web.
sub webExists {
    my ( $this, $web ) = @_;

    return 0 unless defined $web;
    $web =~ s#\.#/#go;

    # Foswiki ships with TWikiCompatibilityPlugin but if it is disabled we
    # do not want the TWiki web to appear as a valid web to anyone.
    if ( $web eq 'TWiki' ) {
        unless ( defined ( $Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}{Enabled} )
          && $Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}{Enabled} == 1 ) {
        return 0;
       }
   }

    my $handler = $this->getHandler( $web, $Foswiki::cfg{WebPrefsTopicName} );
    return $handler->storedDataExists();
}

sub topicExists {
    my ( $this, $web, $topic ) = @_;

    return 0 unless defined $web && $web ne '';
    $web =~ s#\.#/#go;
    return 0 unless defined $topic && $topic ne '';

    my $handler = $this->getHandler( $web, $topic );
    return $handler->storedDataExists();
}

sub getApproxRevTime {
    my ( $this, $web, $topic ) = @_;

    my $handler = $this->getHandler( $web, $topic );
    return $handler->getLatestRevisionTime();
}

sub eachChange {
    my ( $this, $webObject, $time ) = @_;

    my $handler = $this->getHandler($webObject);
    return $handler->eachChange($time);
}

sub eachAttachment {
    my ( $this, $topicObject ) = @_;

    my $handler = $this->getHandler($topicObject);
    my @list    = $handler->getAttachmentList();
    require Foswiki::ListIterator;
    return new Foswiki::ListIterator( \@list );
}

sub eachTopic {
    my ( $this, $webObject ) = @_;

    my $handler = $this->getHandler($webObject);
    my @list    = $handler->getTopicNames();

    require Foswiki::ListIterator;
    return new Foswiki::ListIterator( \@list );
}

sub eachWeb {
    my ( $this, $webObject, $all ) = @_;

    # Undocumented; this fn actually accepts a web name as well. This is
    # to make the recursion more efficient.
    my $web = ref($webObject) ? $webObject->web : $webObject;

    my $handler = $this->getHandler($web);
    my @list    = $handler->getWebNames();
    if ($all) {
        my $root = $web ? "$web/" : '';
        my @expandedList;
        while ( my $wp = shift(@list) ) {
            push( @expandedList, $wp );
            my $it = $this->eachWeb( $root . $wp, $all );
            push( @expandedList, map { "$wp/$_" } $it->all() );
        }
        @list = @expandedList;
    }
    @list = sort(@list);
    require Foswiki::ListIterator;
    return new Foswiki::ListIterator( \@list );
}

sub remove {
    my ( $this, $cUID, $topicObject, $attachment ) = @_;
    ASSERT( $topicObject->web ) if DEBUG;

    my $handler = $this->getHandler( $topicObject, $attachment );
    $handler->remove();

    $this->tellListeners(verb=>'remove', oldmeta=>$topicObject, oldattachment=>$attachment);

    # Only log when deleting topics or attachment, otherwise we would re-create
    # an empty directory with just a .changes. See Item9278
    if ( my $topic = $topicObject->topic ) {
        $handler->recordChange( $cUID, 0, 'Deleted ' . $topic );
    }
    elsif ($attachment) {
        $handler->recordChange( $cUID, 0, 'Deleted attachment ' . $attachment );
    }
}

sub query {
    my ( $this, $query, $inputTopicSet, $session, $options ) = @_;

    my $engine;
    if ( $query->isa('Foswiki::Query::Node') ) {
        unless ( $this->{queryFn} ) {
            eval "require $Foswiki::cfg{Store}{QueryAlgorithm}";
            die
"Bad {Store}{QueryAlgorithm}; suggest you run configure and select a different algorithm\n$@"
              if $@;
            $this->{queryFn} = $Foswiki::cfg{Store}{QueryAlgorithm} . '::query';
        }
        $engine = $this->{queryFn};
    }
    else {
        ASSERT($query->isa('Foswiki::Search::Node')) if DEBUG;
        unless ( $this->{searchQueryFn} ) {
            eval "require $Foswiki::cfg{Store}{SearchAlgorithm}";
            die
"Bad {Store}{SearchAlgorithm}; suggest you run configure and select a different algorithm\n$@"
              if $@;
            $this->{searchQueryFn} =
              $Foswiki::cfg{Store}{SearchAlgorithm} . '::query';
        }
        $engine = $this->{searchQueryFn};
    }

    no strict 'refs';
    return &{$engine}( $query, $inputTopicSet, $session, $options );
    use strict 'refs';
}

sub getRevisionAtTime {
    my ( $this, $topicObject, $time ) = @_;

    my $handler = $this->getHandler($topicObject);
    return $handler->getRevisionAtTime($time);
}

sub getLease {
    my ( $this, $topicObject ) = @_;

    my $handler = $this->getHandler($topicObject);
    my $lease   = $handler->getLease();
    return $lease;
}

sub setLease {
    my ( $this, $topicObject, $lease ) = @_;

    my $handler = $this->getHandler($topicObject);
    $handler->setLease($lease);
}

sub removeSpuriousLeases {
    my ( $this, $web ) = @_;
    my $handler = $this->getHandler($web);
    $handler->removeSpuriousLeases();
}

1;
__END__
Module of Foswiki Enterprise Collaboration Platform, http://Foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. All Rights Reserved.
Foswiki Contributors are listed in the AUTHORS file in the root of
this distribution. NOTE: Please extend that file, not this notice.

Additional copyrights apply to some of the code in this file, as follows

Copyright (C) 2001-2007 Peter Thoeny, peter@thoeny.org
Copyright (C) 2001-2008 TWiki Contributors. All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
