# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Store::VCStore

Partial implementation of Foswiki::Store. The methods of this class are
documented in Foswiki::Store.

This class is an abstract base class for a store implemented using a
version control system, such as RCS. It implements most of the methods
of =Foswiki::Store=. It interacts with the store itself by using a handler
object to interact with each individual file stored in the version control
system. The handler object must implement the interface specified by
=Foswiki::Store::VCHandler=.

The store relies on a handler class to handle all interactions with the
actual version control system. The main responsibility of this class is
to support storing Foswiki data in plain text files, and to ensure that
Foswiki::Meta representing Foswiki data is maintained in synchronisation
with the files in the VC system.

Reference implementations of this base class are =Foswiki::Store::RcsWrap=
and =Fowiki::Store::RcsLite=.

For readers who are familiar with Foswiki version 1.0, the functionality
in this class previously resided in =Foswiki::Store=.

=cut

package Foswiki::Store::VCStore;
use base 'Foswiki::Store';

use strict;
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

=begin TML

---++ ClassMethod new($session, $impl)

Construct a VCStore module, using the chosen handler ($impl) class.

=cut

sub new {
    my ( $class, $session, $impl ) = @_;
    ASSERT($session) if DEBUG;
    ASSERT($impl)    if DEBUG;

    my $this = $class->SUPER::new($session);

    $this->{IMPL} = $impl;
    eval 'use ' . $this->{IMPL} . ' ()';
    if ($@) {
        die "$this->{IMPL} compile failed $@";
    }

    ASSERT( $this->{session} ) if DEBUG;
    ASSERT( $this->{IMPL} )    if DEBUG;

    return $this;
}

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;
    undef $this->{IMPL};
    $this->SUPER::finish();
}

# PRIVATE
# Get a handler for the given object in the store.
sub getHandler {
    my ( $this, $web, $topic, $attachment ) = @_;
    ASSERT( $this->{IMPL} ) if DEBUG;
    return $this->{IMPL}->new( $this->{session}, $web, $topic, $attachment );
}

# Documented in Foswiki::Store
sub readTopic {
    my ( $this, $topicObject, $version ) = @_;
    ASSERT( $topicObject->isa('Foswiki::Meta') ) if DEBUG;

    my $handler = $this->getHandler( $topicObject->web, $topicObject->topic );
    my $text;
    if ($version) {
        $text = $handler->getRevision($version);
    }
    else {
        $text = $handler->getLatestRevision();
    }
    $text =~ s/\r//g;    # Remove carriage returns
    $topicObject->setEmbeddedStoreForm($text);

    return $handler->numRevisions()
      unless $Foswiki::cfg{AutoAttachPubFiles};

    # Override meta with that blended from pub.
    # only check the currently requested topic
    if (   $topicObject->web eq $this->{session}->{webName}
        && $topicObject->topic eq $this->{session}->{topicName} )
    {

        my @knownAttachments = $topicObject->find('FILEATTACHMENT');
        my @attachmentsFoundInPub =
          _synchroniseAttachmentsList( $this, $topicObject->web,
            $topicObject->topic, \@knownAttachments );
        my @validAttachmentsFound;
        foreach my $foundAttachment (@attachmentsFoundInPub) {
            my ( $fileName, $origName ) =
              Foswiki::Sandbox::sanitizeAttachmentName(
                $foundAttachment->{name} );

        #test if the attachment filenam would need sanitizing, if so, ignore it.
            if ( $fileName ne $origName ) {
                $this->{session}->logger->log( 'warning',
                        'AutoAttachPubFiles ignoring '
                      . $origName . ' in '
                      . $topicObject->web . '.'
                      . $topicObject->topic
                      . ' - not a valid Foswiki Attachment filename' );
            }
            else {
                push @validAttachmentsFound, $foundAttachment;
            }
        }

        $topicObject->putAll( 'FILEATTACHMENT', @validAttachmentsFound )
          if @validAttachmentsFound;
    }

    return $handler->numRevisions();
}

# Synchronise the attachment list with what's actually on disk Returns an ARRAY
# of FILEATTACHMENTs. These can be put in the new tom.
#
# This function is only called when the AutoAttachPubFiles configuration
# option is set.
#
# IDEA On Windows machines where the underlying filesystem can store arbitary
# meta data against files, this might replace/fulfil the COMMENT purpose
#
# TODO consider logging when things are added to metadata

sub _synchroniseAttachmentsList {
    my ( $this, $web, $topic, $attachmentsKnownInMeta ) = @_;
    my $session = $this->{session};
    ASSERT( UNIVERSAL::isa( $session, 'Foswiki' ) ) if DEBUG;

    my $handler = $this->getHandler( $web, $topic );
    my %filesListedInPub = $handler->getAttachmentList( $web, $topic );
    my %filesListedInMeta = ();

    # You need the following lines if you want metadata to supplement
    # the filesystem
    if ( defined $attachmentsKnownInMeta ) {
        %filesListedInMeta =
          map { $_->{name} => $_ } @$attachmentsKnownInMeta;
    }

    foreach my $file ( keys %filesListedInPub ) {
        if ( $filesListedInMeta{$file} ) {

            # Bring forward any missing yet wanted attributes
            foreach my $field qw(comment attr user version) {
                if ( $filesListedInMeta{$file}{$field} ) {
                    $filesListedInPub{$file}{$field} =
                      $filesListedInMeta{$file}{$field};
                }
            }
        }
    }

    # A comparison of the keys of the $filesListedInMeta and %filesListedInPub
    # would show files that were in Meta but have disappeared from Pub.

    # Do not change this from array to hash, you would lose the
    # proper attachment sequence
    my @deindexedBecauseMetaDoesnotIndexAttachments = values(%filesListedInPub);

    return @deindexedBecauseMetaDoesnotIndexAttachments;
}

# Documented in Foswiki::Store
sub moveAttachment {
    my (
        $this,           $oldTopicObject, $oldAttachment,
        $newTopicObject, $newAttachment, $cUID
    ) = @_;

    ASSERT($oldTopicObject->isa('Foswiki::Meta')) if DEBUG;
    ASSERT($newTopicObject->isa('Foswiki::Meta')) if DEBUG;
    ASSERT($oldAttachment) if DEBUG;
    ASSERT($newAttachment) if DEBUG;
    ASSERT($cUID) if DEBUG;

    my $handler =
      $this->getHandler( $oldTopicObject->web, $oldTopicObject->topic,
        $oldAttachment );
    $handler->moveAttachment( $newTopicObject->web, $newTopicObject->topic,
        $newAttachment );

    # Modify the cache of the old topic
    my $fileAttachment =
      $oldTopicObject->get( 'FILEATTACHMENT', $oldAttachment );
    $oldTopicObject->remove( 'FILEATTACHMENT', $oldAttachment );
    $oldTopicObject->saveAs(
        undef, undef,
        dontlog => 1,
        comment => 'lost ' . $oldAttachment
    );

    # Add file attachment to new topic
    $fileAttachment->{name} = $newAttachment;
    $fileAttachment->{movefrom} =
        $oldTopicObject->web . '.'
      . $oldTopicObject->topic . '.'
      . $oldAttachment;
    $fileAttachment->{moveby} = $cUID;
    $fileAttachment->{movedto} =
        $newTopicObject->web . '.'
      . $newTopicObject->topic . '.'
      . $newAttachment;
    $fileAttachment->{movedwhen} = time();
    $newTopicObject->putKeyed( 'FILEATTACHMENT', $fileAttachment );

    $newTopicObject->saveAs(
        undef, undef,
        dontlog => 1,
        comment => 'gained' . $newAttachment
    );
}

# Documented in Foswiki::Store
sub getAttachmentStream {
    my ( $this, $topicObject, $att ) = @_;

    my $handler =
      $this->getHandler( $topicObject->web, $topicObject->topic, $att );
    return $handler->getStream();
}

# Documented in Foswiki::Store
sub attachmentExists {
    my ( $this, $web, $topic, $att ) = @_;
    my $handler = $this->getHandler( $web, $topic, $att );
    return $handler->storedDataExists();
}

# Documented in Foswiki::Store
sub moveTopic {
    my ( $this, $oldTopicObject, $newTopicObject, $cUID ) = @_;

    my $handler =
      $this->getHandler( $oldTopicObject->web, $oldTopicObject->topic, '' );
    my $rev = $handler->numRevisions();

    $handler->moveTopic( $newTopicObject->web, $newTopicObject->topic );

    if ( $newTopicObject->web ne $oldTopicObject->web ) {

        # Record that it was moved away
        $handler->recordChange( $cUID, $rev );
    }

    $handler =
      $this->getHandler( $newTopicObject->web, $newTopicObject->topic, '' );
    $handler->recordChange( $cUID, $rev );
}

# Documented in Foswiki::Store
sub moveWeb {
    my ( $this, $oldWebObject, $newWebObject, $cUID ) = @_;

    my $handler = $this->getHandler( $oldWebObject->web );
    $handler->moveWeb( $newWebObject->web );
}

# Documented in Foswiki::Store
sub readAttachment {
    my ( $this, $topicObject, $attachment, $rev ) = @_;

    my $handler =
      $this->getHandler( $topicObject->web, $topicObject->topic, $attachment );
    return $handler->getRevision($rev);
}

# Documented in Foswiki::Store
sub getRevisionNumber {
    my ( $this, $topicObject, $attachment ) = @_;

    my $handler =
      $this->getHandler( $topicObject->web, $topicObject->topic, $attachment );
    return $handler->numRevisions();
}

# Documented in Foswiki::Store
sub getWorkArea {
    my ( $this, $key ) = @_;

    return $this->{IMPL}->getWorkArea($key);
}

# Documented in Foswiki::Store
sub getRevisionDiff {
    my ( $this, $topicObject1, $topicObject2, $contextLines ) = @_;
    ASSERT( defined($contextLines) ) if DEBUG;

    my $rcs = $this->getHandler( $topicObject1->web, $topicObject1->topic );
    return $rcs->revisionDiff(
        $topicObject1->getLoadedRev(),
        $topicObject2->getLoadedRev(),
        $contextLines
    );
}

# Documented in Foswiki::Store
sub getRevisionInfo {
    my ( $this, $topicObject, $rev, $attachment ) = @_;

    $rev ||= 0;

    my $handler =
      $this->getHandler( $topicObject->web, $topicObject->topic, $attachment );

    my $info = $handler->getRevisionInfo($rev);

    if ( !$attachment ) {

        # cache the result
        $topicObject->setRevisionInfo($info);
    }

    return $info;
}

# Documented in Foswiki::Store
sub saveAttachment {
    my ( $this, $topicObject, $name, $stream, $author ) = @_;
    ASSERT($topicObject->isa('Foswiki::Meta')) if DEBUG;
    ASSERT(defined $name) if DEBUG;
    ASSERT(defined $stream) if DEBUG;
    ASSERT(defined $author) if DEBUG;
    my $handler =
      $this->getHandler( $topicObject->web, $topicObject->topic, $name );
    my $currentRev = $handler->numRevisions() || 0;
    my $nextRev = $currentRev + 1;
    $handler->addRevisionFromStream( $stream, 'save attachment', $author );
    return $nextRev;
}

# Documented in Foswiki::Store
sub saveTopic {
    my ( $this, $topicObject, $cUID, $options ) = @_;
    ASSERT($topicObject->isa('Foswiki::Meta')) if DEBUG;
    ASSERT($cUID) if DEBUG;

    my $handler = $this->getHandler( $topicObject->web, $topicObject->topic );
    my $currentRev = $handler->numRevisions() || 0;
    my $nextRev = $currentRev + 1;
    if ( $currentRev && !$options->{forcenewrevision} ) {

        # See if we want to replace the existing top revision
        my $mtime1 = $handler->getTimestamp();
        my $mtime2 = time();

        if (
            abs( $mtime2 - $mtime1 ) <
            $Foswiki::cfg{ReplaceIfEditedAgainWithin} )
        {

            my $info = $handler->getRevisionInfo($currentRev);

            # same user?
            if ( $info->{author} eq $cUID ) {
                $this->repRev( $topicObject, $cUID, %$options );
                return;
            }
        }
    }
    $topicObject->setRevisionInfo(
        {
            date    => $options->{forcedate} || time(),
            author  => $cUID,
            version => $nextRev
        }
    );

    $handler->addRevisionFromText(
        $topicObject->getEmbeddedStoreForm(),
        'save topic', $cUID, $options->{forcedate} );

    # just in case they are not sequential
    $nextRev = $handler->numRevisions();

    my $extra = $options->{minor} ? 'minor' : '';
    $handler->recordChange( $cUID, $nextRev, $extra );

    return $nextRev;
}

# Documented in Foswiki::Store
sub repRev {
    my ( $this, $topicObject, $cUID, %options ) = @_;
    ASSERT( $topicObject->isa( 'Foswiki::Meta' ) ) if DEBUG;
    ASSERT($cUID) if DEBUG;

    my $info = $topicObject->getRevisionInfo();

    if ( $options{forcedate} ) {

        # We are trying to force the rev to be saved with the same date
        # and user as the prior rev. However, exactly the same date may
        # cause some revision control systems to barf, so to avoid this we
        # add 1 minute to the rev time. Note that this mode of operation
        # will normally require sysadmin privilege, as it can result in
        # confused rev dates if abused.
        $info->{date} += 60;
    }
    else {

        # use defaults (current time, current user)
        $info->{date} = time();
        $info->{author} = $cUID;
    }

    # repRev is required so we can tell when a merge is based on something
    # that is *not* the original rev where another users' edit started.
    # See Bugs:Item1897.
    $info->{reprev} = "1.$info->{version}";
    $topicObject->setRevisionInfo($info);

    my $handler = $this->getHandler( $topicObject->web, $topicObject->topic );
    $handler->replaceRevision( $topicObject->getEmbeddedStoreForm(),
        'reprev', $info->{author}, $info->{date} );
}

# Documented in Foswiki::Store
sub delRev {
    my ( $this, $topicObject, $cUID ) = @_;
    ASSERT( $topicObject->isa('Foswiki::Meta')) if DEBUG;
    ASSERT($cUID) if DEBUG;

    my $handler = $this->getHandler( $topicObject->web, $topicObject->topic );
    my $rev = $handler->numRevisions();
    if ( $rev <= 1 ) {
        throw Error::Simple( 'Cannot delete initial revision of '
              . $topicObject->web . '.'
              . $topicObject->topic );
    }
    $handler->deleteRevision();

    # restore last topic from repository
    $handler->restoreLatestRevision( $cUID );

    return $rev;
}

# Documented in Foswiki::Store
# It would be nice to use flock to do this, but the API is unreliable
# (doesn't work on all platforms)
sub lockTopic {
    my ( $this, $topicObject, $cUID ) = @_;
    ASSERT($topicObject->isa('Foswiki::Meta')) if DEBUG;
    ASSERT($cUID) if DEBUG;
    my $handler = $this->getHandler( $topicObject->web, $topicObject->topic );

    while (1) {
        my ( $user, $time ) = $handler->isLocked();
        last if ( !$user || $cUID eq $user );
        $this->{session}->logger->log( 'warning',
                'Lock on '
              . $topicObject->web . '.'
              . $topicObject->topic . ' for '
              . $cUID
              . " denied by $user" );

        # see how old the lock is. If it's older than 2 minutes,
        # break it anyway. Locks are atomic, and should never be
        # held that long, by _any_ process.
        if ( time() - $time > 2 * 60 ) {
            $this->{session}->logger->log( 'warning',
                    $cUID
                  . " broke ${user}s lock on "
                  . $topicObject->web . '.'
                  . $topicObject->topic );
            $handler->setLock( 0, $cUID );
            last;
        }

        # wait a couple of seconds before trying again
        sleep(2);
    }
    $handler->setLock( 1, $cUID );
}

# Documented in Foswiki::Store
sub unlockTopic {
    my ( $this, $topicObject, $cUID ) = @_;

    my $handler = $this->getHandler( $topicObject->web, $topicObject->topic );
    $handler->setLock( 0, $cUID );
}

# Documented in Foswiki::Store
sub webExists {
    my ( $this, $web ) = @_;

    return 0 unless defined $web;
    my $handler = $this->getHandler( $web, $Foswiki::cfg{WebPrefsTopicName} );
    return $handler->storedDataExists();
}

# Documented in Foswiki::Store
sub topicExists {
    my ( $this, $web, $topic ) = @_;

    ASSERT( defined($topic) ) if DEBUG;
    return 0 unless $topic;

    my $handler = $this->getHandler( $web, $topic );
    return $handler->storedDataExists();
}

# Documented in Foswiki::Store
sub getApproxRevTime {
    my ( $this, $web, $topic ) = @_;

    my $handler = $this->getHandler( $web, $topic );
    return $handler->getLatestRevisionTime();
}

# Documented in Foswiki::Store
sub eachChange {
    my ( $this, $webObject, $time ) = @_;

    my $handler = $this->getHandler( $webObject->web );
    return $handler->eachChange($time);
}

# Documented in Foswiki::Store
sub eachTopic {
    my ( $this, $web ) = @_;

    my $handler = $this->getHandler($web);
    my @list    = $handler->getTopicNames();

    require Foswiki::ListIterator;
    return return new Foswiki::ListIterator( \@list );
}

# Documented in Foswiki::Store
sub eachWeb {
    my ( $this, $web, $all ) = @_;
    $web ||= '';

    my $handler = $this->getHandler( $web );
    my @list = $handler->getWebNames();
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

# Documented in Foswiki::Store
sub remove {
    my ( $this, $topicObject, $attachment ) = @_;
    ASSERT( $topicObject->web ) if DEBUG;

    my $handler =
      $this->getHandler( $topicObject->web, $topicObject->topic, $attachment );
    $handler->remove();
}

# Documented in Foswiki::Store
sub copyTopic {
    my ( $this, $fromWeb, $fromTopic, $toWeb, $toTopic ) = @_;

    my $handler = $this->getHandler( $fromWeb, $fromTopic );
    $handler->copyTopic( $toWeb, $toTopic );
}

# Documented in Foswiki::Store
sub searchInWebMetaData {
    my ( $this, $query, $web, $topics ) = @_;
    ASSERT($query);
    ASSERT( UNIVERSAL::isa( $query, 'Foswiki::Query::Node' ) );

    my $handler = $this->getHandler($web);
    return $handler->searchInWebMetaData( $query, $topics, $this );
}

# Documented in Foswiki::Store
sub searchInWebContent {
    my ( $this, $searchString, $web, $topics, $options ) = @_;

    my $handler = $this->getHandler($web);
    return $handler->searchInWebContent( $searchString, $topics, $options );
}

# Documented in Foswiki::Store
sub getRevisionAtTime {
    my ( $this, $topicObject, $time ) = @_;

    my $handler = $this->getHandler( $topicObject->web, $topicObject->topic );
    return $handler->getRevisionAtTime($time);
}

# Documented in Foswiki::Store
sub getLease {
    my ( $this, $topicObject ) = @_;

    my $handler = $this->getHandler( $topicObject->web, $topicObject->topic );
    my $lease = $handler->getLease();
    return $lease;
}

# Documented in Foswiki::Store
sub setLease {
    my ( $this, $topicObject, $lease ) = @_;

    my $handler = $this->getHandler( $topicObject->web, $topicObject->topic );
    $handler->setLease($lease);
}

# Documented in Foswiki::Store
sub removeSpuriousLeases {
    my ( $this, $web ) = @_;
    my $handler = $this->getHandler($web);
    $handler->removeSpuriousLeases();
}

1;
__END__
Module of Foswiki Enterprise Collaboration Platform, http://Foswiki.org/

Copyright (C) 2008-2009 Foswiki Contributors. All Rights Reserved.
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
