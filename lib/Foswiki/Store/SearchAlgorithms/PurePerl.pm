# See bottom of file for license and copyright information

package Foswiki::Store::SearchAlgorithms::PurePerl;

use strict;
use warnings;
use Assert;
use Foswiki::Search::InfoCache;
use Foswiki::Search::ResultSet;

=begin TML

---+ package Foswiki::Store::SearchAlgorithms::PurePerl

Pure perl implementation of the RCS cache search.

---++ search($searchString, $inputTopicSet, $session, $options) -> \%seen
Search .txt files in $dir for $string. See RcsFile::searchInWebContent
for details.

DEPRECATED


=cut

sub search {
    my ( $searchString, $web, $inputTopicSet, $session, $options ) = @_;

    local $/ = "\n";
    my %seen;
    if ( $options->{type} && $options->{type} eq 'regex' ) {

        # Escape /, used as delimiter. This also blocks any attempt to use
        # the search string to execute programs on the server.
        $searchString =~ s!/!\/!g;
    }
    else {

        # Escape non-word chars in search string for plain text search
        $searchString =~ s/(\W)/\\$1/g;
    }

    # *Compatibility; this should no longer be required, as usage of
    # \< and \> has been removed in the core.
    # Convert GNU grep \< \> syntax to \b
    $searchString =~ s/(?<!\\)\\[<>]/\\b/g;

    $searchString =~ s/^(.*)$/\\b$1\\b/go if $options->{'wordboundaries'};
    my $doMatch;
    if ( $options->{casesensitive} ) {
        $doMatch = sub { $_[0] =~ m/$searchString/ };
    }
    else {
        $doMatch = sub { $_[0] =~ m/$searchString/i };
    }

    #SMELL, TODO, replace with Store call.
    my $sDir = $Foswiki::cfg{DataDir} . '/' . $web . '/';
    $inputTopicSet->reset();
  FILE:
    while ( $inputTopicSet->hasNext() ) {
        my $webtopic = $inputTopicSet->next();
        my ( $Iweb, $topic ) =
          Foswiki::Func::normalizeWebTopicName( $web, $webtopic );

#TODO: need to BM if this is faster than doing it via an object in the MetaCache.
        my $file;
        if (open( $file, '<', "$sDir/$topic.txt" )) {
            while ( my $line = <$file> ) {
                if ( &$doMatch($line) ) {
                    chomp($line);
                    push( @{ $seen{$webtopic} }, $line );
                    if ( $options->{files_without_match} ) {
                        close($file);
                        next FILE;
                    }
                }
            }
            close($file);
        }
    }
    return \%seen;
}

=begin TML

this is the new way -

=cut

sub query {
    my ( $query, $inputTopicSet, $session, $options ) = @_;

    if ( ( @{ $query->{tokens} } ) == 0 ) {
        return new Foswiki::Search::InfoCache( $session, '' );
    }

    my $webNames = $options->{web}       || '';
    my $recurse  = $options->{'recurse'} || '';
    my $isAdmin  = $session->{users}->isAdmin( $session->{user} );

    my $searchAllFlag = ( $webNames =~ /(^|[\,\s])(all|on)([\,\s]|$)/i );
    my @webs = Foswiki::Search::InfoCache::_getListOfWebs( $webNames, $recurse,
        $searchAllFlag );

    my @resultCacheList;
    foreach my $web (@webs) {

        # can't process what ain't thar
        next unless $session->webExists($web);

        my $webObject = Foswiki::Meta->new( $session, $web );
        my $thisWebNoSearchAll = Foswiki::isTrue( $webObject->getPreference('NOSEARCHALL') );

        # make sure we can report this web on an 'all' search
        # DON'T filter out unless it's part of an 'all' search.
        next
          if ( $searchAllFlag
            && !$isAdmin
            && ( $thisWebNoSearchAll || $web =~ /^[\.\_]/ )
            && $web ne $session->{webName} );

        my $infoCache =
          _webQuery( $query, $web, $inputTopicSet, $session, $options );
        $infoCache->sortResults($options);
        push( @resultCacheList, $infoCache );
    }
    my $resultset =
      new Foswiki::Search::ResultSet( \@resultCacheList, $options->{groupby},
        $options->{order}, Foswiki::isTrue( $options->{reverse} ) );

    #TODO: $options should become redundant
    $resultset->sortResults($options);
    return $resultset;
}

#ok, for initial validation, naively call the code with a web.
sub _webQuery {
    my ( $query, $web, $inputTopicSet, $session, $options ) = @_;
    ASSERT( scalar( @{ $query->{tokens} } ) > 0 ) if DEBUG;

    # default scope is 'text'
    $options->{'scope'} = 'text'
      unless ( defined( $options->{'scope'} )
        && $options->{'scope'} =~ /^(topic|all)$/ );

    my $topicSet = $inputTopicSet;
    if ( !defined($topicSet) ) {

        #then we start with the whole web?
        #TODO: i'm sure that is a flawed assumption
        my $webObject = Foswiki::Meta->new( $session, $web );
        $topicSet =
          Foswiki::Search::InfoCache::getTopicListIterator( $webObject,
            $options );
    }
    ASSERT( UNIVERSAL::isa( $topicSet, 'Foswiki::Iterator' ) ) if DEBUG;

#print STDERR "######## PurePerl search ($web) tokens ".scalar(@{$query->{tokens}})." : ".join(',', @{$query->{tokens}})."\n";
# AND search - search once for each token, ANDing result together
    foreach my $token ( @{ $query->{tokens} } ) {

        my $tokenCopy = $token;

        # flag for AND NOT search
        my $invertSearch = 0;
        $invertSearch = ( $tokenCopy =~ s/^\!//o );

        # scope can be 'topic' (default), 'text' or "all"
        # scope='topic', e.g. Perl search on topic name:
        my %topicMatches;
        unless ( $options->{'scope'} eq 'text' ) {
            my $qtoken = $tokenCopy;

            # FIXME I18N
            $qtoken = quotemeta($qtoken)
              if ( $options->{'type'} ne 'regex' );

            my @topicList;
            $topicSet->reset();
            while ( $topicSet->hasNext() ) {
                my $webtopic = $topicSet->next();
                my ( $Iweb, $topic ) =
                  Foswiki::Func::normalizeWebTopicName( $web, $webtopic );

                if ( $options->{'casesensitive'} ) {

                    # fix for Codev.SearchWithNoPipe
                    $topicMatches{$webtopic} = 1 if ( $topic =~ /$qtoken/ );
                }
                else {
                    $topicMatches{$webtopic} = 1 if ( $topic =~ /$qtoken/i );
                }
            }
        }

        # scope='text', e.g. grep search on topic text:
        my $textMatches;
        unless ( $options->{'scope'} eq 'topic' ) {
            $textMatches =
              search( $tokenCopy, $web, $topicSet, $session->{store},
                $options );
        }

        #bring the text matches into the topicMatch hash
        if ($textMatches) {
            @topicMatches{ keys %$textMatches } = values %$textMatches;
        }

        my @scopeTextList = ();
        if ($invertSearch) {
            $topicSet->reset();
            while ( $topicSet->hasNext() ) {
                my $webtopic = $topicSet->next();

                if ( $topicMatches{$webtopic} ) {
                }
                else {
                    push( @scopeTextList, $webtopic );
                }
            }
        }
        else {

            #TODO: the sad thing about this is we lose info
            @scopeTextList = keys(%topicMatches);
        }

        $topicSet =
          new Foswiki::Search::InfoCache( $Foswiki::Plugins::SESSION, $web,
            \@scopeTextList );
    }

    return $topicSet;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2007 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
