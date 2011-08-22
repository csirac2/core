package Foswiki::Store;

=pod

=head1 NAME

Foswiki::Store - Factory for Foswiki Data Objects - webs, topics, attachments...

=head1 SYNOPSIS

  my $object = Foswiki::Store->new(
      foo  => 'bar',
      flag => 1,
  );
  
  $object->dummy;

=head1 DESCRIPTION

The Foswiki::Store singleton is a factory object that manipulates data objects (traditionally called webs, topic and attachments)
by delegating requests to specific store implementations.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;

our $VERSION = '0.01';

use Error qw( :try );
use Assert;

use Foswiki::Address;

=pod

=head2 ClassMethod load(address=>$address, cuid=>$cuid, create=>1, writeable=>1) -> $dataObject
   * =address=>$address= - (required) address of object - can be:
      * ($web, $topic, $attachment, $rev) list
      * 'web.topic@4' style
      * Foswiki::Address
      * Foswiki::Object impl
   * cuid=>$cuid (canonical user id) - if undefined, presume 'admin' (or no perms check) access
   * create=>1
   * writeable=>1
   

returns an object of the appropriate type from the Foswiki::Object:: hieracy

TODO: note that most of the methods here will have the same codepath as load(), 
so it might be better to write it all as a switchboard..

=cut

sub load {
    my %args = @_;

    %args{address} = Foswiki::Address->new(%args{address}) unless (%args{address}->isa('Foswiki::Address'));
    my $access_type = $args{writeable}?'CHANGE':'VIEW';
    
    #see if we are _able_ to test permissions using just an unloaded topic, if not, fall through to load&then test
    throw AccessException() unless Foswiki::Permissions::hasAccess(%args{address}, $access_type,  $args{cuid}, dontload=>1) if (defined($args{cuid})); 

    #$cfg::Foswiki{Stores} is an ordered list, managed by configure that prioritises the cache stores first.
    foreach my $impl (@{$cfg::Foswiki{Stores}}) {
        #the impl is also able to throw exceptions - as there might be a store based permissions impl
        my $object = $impl::impl->load(%args);
        last if ($defined($object));
    }
    if (not defined($object) and $args{create}) {
       $object = create(%args);
    }
    throw DoesNotExist() unless (defined($object);
    
    foreach my $impl (@{$cfg::Foswiki{ListenerStores}}) {
        $impl::impl->loaded(%args{address}, $object);
    }
    #can't do any better with the __current__ ACL impl, but there should be a call before the readData for real store-fastening
    throw AccessException() unless Foswiki::Permissions::hasAccess($object, $access_type,  $args{cuid}) if (defined($args{cuid})); 
    return $object;
}


=pod

=head2 ClassMethod save(object=>$address, cuid=>$cuid, create=>1, writeable=>1, forcenewrevision=>0, ...) -> $integer?
   * =object=>$object= - (required) Foswiki::Object impl
   * cuid=>$cuid (canonical user id) - if undefined, presume 'admin' (or no perms check) access

Save a topic or attachment _without_ invoking plugin handlers.
   * =object= - Foswiki::Meta for the topic
   * =cuid= - cUID of user doing the saving
   * =forcenewrevision= - force a new revision even if one isn't needed
   * =forcedate= - force the revision date to be this (epoch secs)
   * =minor= - True if this is a minor change (used in log)
   * =author= - cUID of author of the change
   * =reprev=

Returns the new revision identifier.

=cut

sub save {
}


=pod

=head2 ClassMethod delete(address=>$address, cuid=>$cuid, -> success?
   * =address= - (required) Address - can be a specific revision, in which case it requests the store to =delRev=
   * cuid=>$cuid (canonical user id) - if undefined, presume 'admin' (or no perms check) access

delete a topic or attachment _without_ invoking plugin handlers.
   * =object= - Foswiki::Meta for the topic
   * =cuid= - cUID of user doing the saving

=cut

sub delete {
}

=pod

=head2 ClassMethod move(from=>$address, to=>$address, cuid=>$cuid) -> success?
   * =from=>$address= - (required) address of object - can be:
      * ($web, $topic, $attachment, $rev) list
      * 'web.topic@4' style
      * Foswiki::Address
      * Foswiki::Object impl
   * =to=>$address= - (required) address of object - can be:
      * ($web, $topic, $attachment, $rev) list
      * 'web.topic@4' style
      * Foswiki::Address
      * Foswiki::Object impl
   * cuid=>$cuid (canonical user id) - if undefined, presume 'admin' (or no perms check) access

=cut

sub move {
}


=pod

=head2 ClassMethod copy(from=>$address, to=>$address, cuid=>$cuid) -> success?
   * =from=>$address= - (required) address of object - can be:
      * ($web, $topic, $attachment, $rev) list
      * 'web.topic@4' style
      * Foswiki::Address
      * Foswiki::Object impl
   * =to=>$address= - (required) address of object - can be:
      * ($web, $topic, $attachment, $rev) list
      * 'web.topic@4' style
      * Foswiki::Address
      * Foswiki::Object impl
   * cuid=>$cuid (canonical user id) - if undefined, presume 'admin' (or no perms check) access

=cut

sub copy {
}


=pod

=head2 ClassMethod exists(address=>$address, cuid=>$cuid) -> bool
   * =address=>$address= - (required) address of object - can be:
      * ($web, $topic, $attachment, $rev) list
      * 'web.topic@4' style
      * Foswiki::Address
      * Foswiki::Object impl
   * cuid=>$cuid (canonical user id) - if undefined, presume 'admin' (or no perms check) access

=cut

sub exists {
}

=pod

=head2 ClassMethod getRevisionHistory(address=>$address, cuid=>$cuid) -> $iterator
   * =address=>$address= - (required) address of object - can be:
      * ($web, $topic, $attachment, $rev) list
      * 'web.topic@4' style
      * Foswiki::Address
      * Foswiki::Object impl
   * cuid=>$cuid (canonical user id) - if undefined, presume 'admin' (or no perms check) access
   
Get an iterator over the list of revisions of the object. The iterator returns
the revision identifiers (which will usually be numbers) starting with the most recent revision.

if there are no versions, we probably return an empty itr

=cut

sub getRevisionHistory {
}

=pod

=head2 ClassMethod getNextRevision ( address=>$address  ) -> $revision
   * =$address= - address of datum
   
Get the ientifier for the next revision of the topic. That is, the identifier
for the revision that we will create when we next save.

=cut

# SMELL: There's an inherent race condition with doing this, but it's always
# been there so I guess we can live with it.
sub getNextRevision{
}

=pod

=head2 ClassMethod getRevisionDiff(from=>$address, to=>$address, cuid=>$cuid, contextLines=>$contextLines) -> \@diffArray

Get difference between two versions of the same topic. The differences are
computed over the embedded store form.

Return reference to an array of differences
   * =from=>$address= - (required) address of object - can be:
      * ($web, $topic, $attachment, $rev) list
      * 'web.topic@4' style
      * Foswiki::Address
      * Foswiki::Object impl
   * =to=>$address= - (required) address of object - can be:
      * ($web, $topic, $attachment, $rev) list
      * 'web.topic@4' style
      * Foswiki::Address
      * Foswiki::Object impl
   * cuid=>$cuid (canonical user id) - if undefined, presume 'admin' (or no perms check) access
   * =$contextLines= - number of lines of context required

Each difference is of the form [ $type, $right, $left ] where
| *type* | *Means* |
| =+= | Added |
| =-= | Deleted |
| =c= | Changed |
| =u= | Unchanged |
| =l= | Line Number |

=cut

sub getRevisionDiff {
}

=pod

=head2 ClassMethod getVersionInfo(address=>$addres, cuid=>$cuid) -> \%info

   * =address=>$address= - (required) address of object - can be:
      * ($web, $topic, $attachment, $rev) list
      * 'web.topic@4' style
      * Foswiki::Address
      * Foswiki::Object impl
   * cuid=>$cuid (canonical user id) - if undefined, presume 'admin' (or no perms check) access
   
Return %info with at least:
| date | in epochSec |
| user | user *object* |
| version | the revision number |
| comment | comment in the VC system, may or may not be the same as the comment in embedded meta-data |

=cut

# Formerly know as getRevisionInfo.
sub getVersionInfo {
}

=pod

=head2 ClassMethod atomicLockInfo( $topicObject ) -> ($cUID, $time)
If there is a lock on the topic, return it.

=cut

sub atomicLockInfo {
    my ( $this, $topicObject ) = @_;
    die "Abstract base class";
}

=pod

=head2 ClassMethod atomicLock( $topicObject, $cUID )

   * =$topicObject= - Foswiki::Meta topic object
   * =$cUID= cUID of user doing the locking
Grab a topic lock on the given topic.

=cut

sub atomicLock {
    my ( $this, $topicObject, $cUID ) = @_;
    die "Abstract base class";
}

=pod

=head2 ClassMethod atomicUnlock( $topicObject )

   * =$topicObject= - Foswiki::Meta topic object
Release the topic lock on the given topic. A topic lock will cause other
processes that also try to claim a lock to block. It is important to
release a topic lock after a guard section is complete. This should
normally be done in a 'finally' block. See man Error for more info.

Topic locks are used to make store operations atomic. They are
_note_ the locks used when a topic is edited; those are Leases
(see =getLease=)

=cut

sub atomicUnlock {
    my ( $this, $topicObject ) = @_;
    die "Abstract base class";
}

=pod

=head2 ClassMethod getApproxRevTime (  $web, $topic  ) -> $epochSecs

Get an approximate rev time for the latest rev of the topic. This method
is used to optimise searching. Needs to be as fast as possible.

=cut

sub getApproxRevTime {
    my ( $this, $web, $topic ) = @_;
    die "Abstract base class";
}

=pod

=head2 ClassMethod eachChange( $web, $time ) -> $iterator

Get an iterator over the list of all the changes in the given web between
=$time= and now. $time is a time in seconds since 1st Jan 1970, and is not
guaranteed to return any changes that occurred before (now -
{Store}{RememberChangesFor}). Changes are returned in most-recent-first
order.

=cut

sub eachChange {
    my ( $this, $web, $time ) = @_;
    die "Abstract base class";
}

=pod

=head2 ClassMethod query($query, $inputTopicSet, $session, \%options) -> $outputTopicSet

Search for data in the store (not web based).
   * =$query= either a =Foswiki::Search::Node= or a =Foswiki::Query::Node=.
   * =$inputTopicSet= is a reference to an iterator containing a list
     of topic in this web, if set to undef, the search/query algo will
     create a new iterator using eachTopic() 
     and the topic and excludetopics options

Returns a =Foswiki::Search::InfoCache= iterator

This will become a 'query engine' factory that will allow us to plug in
different query 'types' (Sven has code for 'tag' and 'attachment' waiting
for this)

=cut

sub query {
}

=pod

=head2 ClassMethod getRevisionAtTime( $topicObject, $time ) -> $rev

   * =$topicObject= - topic
   * =$time= - time (in epoch secs) for the rev

Get the revision identifier of a topic at a specific time.
Returns a single-digit rev number or undef if it couldn't be determined
(either because the topic isn't that old, or there was a problem)

=cut

sub getRevisionAtTime {
    my ( $this, $topicObject, $time ) = @_;
    die "Abstract base class";
}

=pod

=head2 ClassMethod getLease( $topicObject ) -> $lease

   * =$topicObject= - topic

If there is an lease on the topic, return the lease, otherwise undef.
A lease is a block of meta-information about a topic that can be
recovered (this is a hash containing =user=, =taken= and =expires=).
Leases are taken out when a topic is edited. Only one lease
can be active on a topic at a time. Leases are used to warn if
another user is already editing a topic.

=cut

sub getLease {
    my( $this, $topicObject ) = @_;
    die "Abstract base class";
}

=pod

=head2 ClassMethod setLease( $topicObject, $length )

   * =$topicObject= - Foswiki::Meta topic object
Take out an lease on the given topic for this user for $length seconds.

See =getLease= for more details about Leases.

=cut

sub setLease {
    my( $this, $topicObject, $lease ) = @_;
    die "Abstract base class";
}

=pod

=head2 ClassMethod removeSpuriousLeases( $web )

Remove leases that are not related to a topic. These can get left behind in
some store implementations when a topic is created, but never saved.

=cut

sub removeSpuriousLeases {
    #my( $this, $web ) = @_;
    # default is a no-op
}

1;

=pod

=head1 SUPPORT

see http://foswiki.org

=head1 AUTHOR

Author: Sven Dowideit, http://fosiki.com

Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2011 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.


=cut
