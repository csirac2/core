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

use Foswiki::Store::Interfaces::Store ();
our @ISA = ('Foswiki::Store::Interfaces::Store');

use Assert;
use Error qw( :try );

use Foswiki          ();
use Foswiki::Meta    ();
use Foswiki::Sandbox ();
use Foswiki::Serialise();

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

    #my ( $this, $web, $topic, $args{attachment} ) = @_;
    ASSERT( 0, "Must be implemented by subclasses" ) if DEBUG;
}

sub readTopic {
    my ( $this, %args ) = @_;

    my ( $gotRev, $isLatest ) = $this->askListeners($args{address}, $args{rev});

    if ( defined($gotRev) and ( $gotRev > 0 or ($isLatest)) ) {
        return ( $gotRev, $isLatest );
    }
    ASSERT( not $isLatest ) if DEBUG;

    my $handler = $this->getHandler($args{address});
    $isLatest = 0;

    # check that the requested revision actually exists
    if ( defined $args{rev} ) {
        if ( !$args{rev} || !$handler->revisionExists($args{rev}) ) {
            $args{rev} = $handler->getLatestRevisionID();
        }
    }

    ( my $text, $isLatest ) = $handler->getRevision($args{rev});
    unless ( defined $text ) {
        ASSERT( not $isLatest ) if DEBUG;
        return ( undef, $isLatest );
    }

    $text =~ s/\r//g;    # Remove carriage returns
    $args{address}->setEmbeddedStoreForm($text);

    $gotRev = $args{rev};
    unless ( defined $gotRev ) {

        # First try the just-loaded text for the revision
        my $ri = $args{address}->get('TOPICINFO');
        if ( defined($ri) ) {

            # SMELL: this can end up overriding a correct rev no (the one
            # requested) with an incorrect one (the one in the TOPICINFO)
            $gotRev = $ri->{version};
        }
    }
    if ( !$gotRev ) {

        # No revision from any other source; must be latest
        $gotRev = $handler->getLatestRevisionID();
        ASSERT( defined $gotRev ) if DEBUG;
    }

    # Add attachments that are new from reading the pub directory.
    # Only check the currently requested topic.
    if (   $Foswiki::cfg{RCS}{AutoAttachPubFiles}
        && $args{address}->isSessionTopic() )
    {
        my @knownAttachments = $args{address}->find('FILEATTACHMENT');
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
                  . $args{address}->getPath()
                  . ' - not a valid Foswiki Attachment filename';
            }
            else {
                push @validAttachmentsFound, $foundAttachment;
                $this->tellListeners(
                    verb          => 'autoattach',
                    newmeta       => $args{address},
                    newattachment => $foundAttachment
                );
            }
        }

        $args{address}->putAll( 'FILEATTACHMENT', @validAttachmentsFound )
          if @validAttachmentsFound;
    }

    ASSERT( defined($gotRev) ) if DEBUG;
    return ( $gotRev, $isLatest );
}

sub moveAttachment {
    my ( $this, %args )
      = @_;

    my $handler = $this->getHandler( $args{from}, $args{fromattachment} );
    if ( $handler->storedDataExists() ) {
        $handler->moveAttachment( $this, $args{address}->web,
            $args{address}->topic, $args{attachment} );
        $this->tellListeners(
            verb          => 'update',
            oldmeta       => $args{from},
            oldattachment => $args{fromattachment},
            newmeta       => $args{address},
            newattachment => $args{attachment}
        );
        $handler->recordChange( $args{cuid}, 0 );
    }
}

sub copyAttachment {
    my ( $this, %args )
      = @_;

    my $handler = $this->getHandler( $args{from}, $args{fromattachment} );
    if ( $handler->storedDataExists() ) {
        $handler->copyAttachment( $this, $args{address}->web,
            $args{address}->topic, $args{attachment} );
        $this->tellListeners(
            verb          => 'insert',
            newmeta       => $args{address},
            newattachment => $args{attachment}
        );
        $handler->recordChange( $args{cuid}, 0 );
    }
}

sub attachmentExists {
    my ( $this, %args ) = @_;
    my $handler = $this->getHandler( $args{address}, $args{attachment} );
    return $handler->storedDataExists();
}

sub moveTopic {
    my ( $this, %args ) = @_;
    ASSERT($args{cuid}) if DEBUG;

    my $handler = $this->getHandler( $args{from}, '' );
    $args{rev} = $handler->getLatestRevisionID();

    $handler->moveTopic( $this, $args{address}->web, $args{address}->topic );

    $this->tellListeners(
        verb    => 'update',
        oldmeta => $args{from},
        newmeta => $args{address}
    );

    if ( $args{address}->web ne $args{from}->web ) {

        # Record that it was moved away
        $handler->recordChange( $args{cuid}, $args{rev} );
    }

    $handler = $this->getHandler( $args{address}, '' );
    $handler->recordChange( $args{cuid}, $args{rev} );
}

sub moveWeb {
    my ( $this, %args ) = @_;
    ASSERT($args{cuid}) if DEBUG;

    my $handler = $this->getHandler($args{from});
    $handler->moveWeb( $args{address}->web );

    $this->tellListeners(
        verb    => 'update',
        oldmeta => $args{from},
        newmeta => $args{address}
    );

    # We have to log in the new web, otherwise we would re-create the dir with
    # a useless .changes. See Item9278
    $handler = $this->getHandler($args{address});
    $handler->recordChange( $args{cuid}, 0, 'Moved from ' . $args{from}->web );
}

sub testAttachment {
    my ( $this, %args ) = @_;
    my $handler = $this->getHandler( $args{address}, $args{attachment} );
    return $handler->test($args{test});
}

sub openAttachment {
    my ( $this, %args ) = @_;

    my $handler = $this->getHandler( $args{address}, $args{attachment} );
    return $handler->openStream( $args{mode}, %args );
}

sub getRevisionHistory {
    my ( $this, %args ) = @_;
    
    my $itr = $this->askListenersRevisionHistory($args{address}, $args{attachment});

    if ( defined($itr) ) {
        return $itr;
    }

    my $handler = $this->getHandler( $args{address}, $args{attachment} );
    return $handler->getRevisionHistory();
}

sub getNextRevision {
    my ( $this, %args ) = @_;
    my $handler = $this->getHandler($args{address});
    return $handler->getNextRevisionID();
}

sub getRevisionDiff {
    my ( $this, %args ) = @_;
    ASSERT( defined($args{contextLines}) ) if DEBUG;

    my $rcs = $this->getHandler($args{address});
    return $rcs->revisionDiff( $args{address}->getLoadedRev(), $args{rev},
        $args{contextLines} );
}

sub getAttachmentVersionInfo {
    my ( $this, %args ) = @_;
    my $handler = $this->getHandler( $args{address}, $args{attachment} );
    return $handler->getInfo( $args{rev} || 0 );
}

sub getVersionInfo {
    my ( $this, %args ) = @_;
    my $handler = $this->getHandler($args{address});
    return $handler->getInfo( $args{address}->getLoadedRev() );
}

sub saveAttachment {
    my ( $this, %args ) = @_;
    my $handler    = $this->getHandler( $args{address}, $args{name} );
    my $currentRev = $handler->getLatestRevisionID();
    my $nextRev    = $currentRev + 1;
    my $verb = ( $args{address}->hasAttachment($args{name}) ) ? 'update' : 'insert';
    $handler->addRevisionFromStream( $args{stream}, 'save attachment', $args{cuid} );
    $this->tellListeners(
        verb          => $verb,
        newmeta       => $args{address},
        newattachment => $args{name}
    );
    $handler->recordChange( $args{cuid}, $nextRev );
    return $nextRev;
}

sub saveTopic {
    my ( $this, %args, $options ) = @_;
    ASSERT( $args{address}->isa('Foswiki::Meta') ) if DEBUG;
    ASSERT($args{cuid}) if DEBUG;

    my $handler = $this->getHandler($args{address});

    my $verb = ( $args{address}->existsInStore() ) ? 'update' : 'insert';

    $handler->addRevisionFromText( $args{address}->getEmbeddedStoreForm(),
        'save topic', $args{cuid}, $options->{forcedate} );

    # just in case they are not sequential
    my $nextRev = $handler->getLatestRevisionID();

    my $extra = $options->{minor} ? 'minor' : '';
    $handler->recordChange( $args{cuid}, $nextRev, $extra );

    $this->tellListeners( verb => $verb, newmeta => $args{address} );

    return $nextRev;
}

sub repRev {
    my ( $this, %args, %options ) = @_;
    ASSERT( $args{address}->isa('Foswiki::Meta') ) if DEBUG;
    ASSERT($args{cuid}) if DEBUG;

    my $info    = $args{address}->getRevisionInfo();
    my $handler = $this->getHandler($args{address});
    $handler->replaceRevision( $args{address}->getEmbeddedStoreForm(),
        'reprev', $info->{author}, $info->{date} );
    $args{rev} = $handler->getLatestRevisionID();
    $handler->recordChange( $args{cuid}, $args{rev}, 'minor, reprev' );

    $this->tellListeners( verb => 'update', newmeta => $args{address} );

    return $args{rev};
}

sub delRev {
    my ( $this, %args ) = @_;
    ASSERT( $args{address}->isa('Foswiki::Meta') ) if DEBUG;
    ASSERT($args{cuid}) if DEBUG;

    my $handler = $this->getHandler($args{address});
    $args{rev}     = $handler->getLatestRevisionID();
    if ( $args{rev} <= 1 ) {
        throw Error::Simple( 'Cannot delete initial revision of '
              . $args{address}->web . '.'
              . $args{address}->topic );
    }
    $handler->deleteRevision();

    # restore last topic from repository
    $handler->restoreLatestRevision($args{cuid});

    # reload the topic object
    $args{address}->unload();
    $args{address}->loadVersion();

    $this->tellListeners( verb => 'update', newmeta => $args{address} );

    $handler->recordChange( $args{cuid}, $args{rev} );

    return $args{rev};
}

sub atomicLockInfo {
    my ( $this, %args ) = @_;
    my $handler = $this->getHandler($args{address});
    return $handler->isLocked();
}

# It would be nice to use flock to do this, but the API is unreliable
# (doesn't work on all platforms)
sub atomicLock {
    my ( $this, %args ) = @_;
    my $handler = $this->getHandler($args{address});
    $handler->setLock( 1, $args{cuid} );
}

sub atomicUnlock {
    my ( $this, %args ) = @_;

    my $handler = $this->getHandler($args{address});
    $handler->setLock( 0, $args{cuid} );
}

# A web _has_ to have a preferences topic to be a web.
sub webExists {
    my ( $this, $web ) = @_;

    return 0 unless defined $web;
    $web =~ s#\.#/#go;

    # Foswiki ships with TWikiCompatibilityPlugin but if it is disabled we
    # do not want the TWiki web to appear as a valid web to anyone.
    if ( $web eq 'TWiki' ) {
        unless ( exists $Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}
            && defined $Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}{Enabled}
            && $Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}{Enabled} == 1 )
        {
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
    my ( $this, %args ) = @_;

    my $handler = $this->getHandler($args{address});
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
    my ( $this, %args ) = @_;
    ASSERT( $args{address}->web ) if DEBUG;

    my $handler = $this->getHandler( $args{address}, $args{attachment} );
    my $result = $handler->remove();

    $this->tellListeners(
        verb          => 'remove',
        oldmeta       => $args{address},
        oldattachment => $args{attachment}
    );

    # Only log when deleting topics or attachment, otherwise we would re-create
    # an empty directory with just a .changes. See Item9278
    if ( my $topic = $args{address}->topic ) {
        $handler->recordChange( $args{cuid}, 0, 'Deleted ' . $topic );
    }
    elsif ($args{attachment}) {
        $handler->recordChange( $args{cuid}, 0, 'Deleted attachment ' . $args{attachment} );
    }
    
    return (defined($result)?$result:1);    #return true unless handler returns false.
}

sub query {
    my ( $this, $query, $inputTopicSet, $session, $options ) = @_;

    my $engine;
    if ( $query->isa('Foswiki::Query::Node') ) {
        unless ( $this->{queryObj} ) {
            my $module = $Foswiki::cfg{Store}{QueryAlgorithm};
            eval "require $module";
            die
"Bad {Store}{QueryAlgorithm}; suggest you run configure and select a different algorithm\n$@"
              if $@;
            $this->{queryObj} = $module->new();
        }
        $engine = $this->{queryObj};
    }
    else {
        ASSERT( $query->isa('Foswiki::Search::Node') ) if DEBUG;
        unless ( $this->{searchQueryObj} ) {
            my $module = $Foswiki::cfg{Store}{SearchAlgorithm};
            eval "require $module";
            die
"Bad {Store}{SearchAlgorithm}; suggest you run configure and select a different algorithm\n$@"
              if $@;
            $this->{searchQueryObj} = $module->new();
        }
        $engine = $this->{searchQueryObj};
    }

    no strict 'refs';
    return $engine->query( $query, $inputTopicSet, $session, $options );
    use strict 'refs';
}

sub getRevisionAtTime {
    my ( $this, %args ) = @_;

    my $handler = $this->getHandler($args{address});
    return $handler->getRevisionAtTime($args{time});
}

sub getLease {
    my ( $this, %args ) = @_;

    my $handler = $this->getHandler($args{address});
    my $lease   = $handler->getLease();
    return $lease;
}

sub setLease {
    my ( $this, %args ) = @_;

    my $handler = $this->getHandler($args{address});
    $handler->setLease($args{lease});
}

sub removeSpuriousLeases {
    my ( $this, $web ) = @_;
    my $handler = $this->getHandler($web);
    $handler->removeSpuriousLeases();
}
############################################################################
# new foswiki 2.0 API methods

sub save {
    my $this = shift;
    my %args = @_;
    ASSERT($args{address}) if DEBUG;
    my $type = $args{address}->type();
#    ASSERT($type) if DEBUG;
    if ($type eq 'webpath') {
        return $this->saveWeb($args{address}->web);
    } elsif ($type eq 'topic') {
        return $this->saveTopic(%args);
    } 
    die "can't call save(".$args{address}->getPath().")" if DEBUG;
}

sub exists {
    my $this = shift;
    my %args = @_;
    ASSERT($args{address}) if DEBUG;
    my $type = $args{address}->type();
#    ASSERT($type) if DEBUG;
    if ($type eq 'webpath') {
        return $this->webExists($args{address}->web);
    } elsif ($type eq 'topic') {
        return $this->topicExists($args{address}->web, $args{address}->topic);
    } 
    die "can't call exists(".$args{address}->getPath().") cos its type = $type " if DEBUG;
}

sub create {
    my $this = shift;
    my %args = @_;
    ASSERT($args{address}) if DEBUG;
    my $type = $args{address}->type();
    ASSERT($type) if DEBUG;
    if ($type eq 'webpath') {
        my $newResource =  Foswiki::Meta->NEWnew( @_ );
        return $newResource;
    } elsif ($type eq 'topic') {
        my $newResource =  Foswiki::Meta->NEWnew( @_ );
        return $newResource;
    } 
    die "can't call load($type)" if DEBUG;
}

sub load {
    my $this = shift;
    my %args = @_;
    ASSERT($args{address}) if DEBUG;
    my $type = $args{address}->type();
    ASSERT($type) if DEBUG;
    if ($type eq 'webpath') {
        my $newResource =  Foswiki::Meta->NEWnew( @_ );
        return $newResource;
    } elsif ($type eq 'topic') {
        my $handler = $this->getHandler($args{address});

        # check that the requested revision actually exists
        $args{rev} = $args{address}->rev();
        if ( defined $args{rev} ) {
            if ( !$args{rev} || !$handler->revisionExists($args{rev}) ) {
                $args{rev} = $handler->getLatestRevisionID();
            }
        }

        #read the raw text file.
        my ( $text, $isLatest ) = $handler->getRevision($args{rev});
        unless ( defined $text ) {
            ASSERT( not $isLatest ) if DEBUG;
            return undef;
        }

        #parse it into a hash so we can use it to create a new Foswiki::Object
        #$text =~ s/\r//g;    # Remove carriage returns
        #$args{address}->setEmbeddedStoreForm($text);
        my $parsedObj = Foswiki::Serialise::deserialise( $Foswiki::Plugins::SESSION, $text, 'embedded' );
      
#        return $this->topicExists($args{address}->web, $args{address}->topic);
        my $newResource =  Foswiki::Meta->NEWnew( data=>$parsedObj, @_ );
        return $newResource;
    } 
    die "can't call load($type)" if DEBUG;
}

sub log {
    my $self = shift;
    #IMPLEMENTME
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
