# See bottom of file for license and copyright information

package Foswiki::Store::SearchAlgorithms::Forking;

use strict;
use warnings;
use Assert;
use Foswiki::Search::InfoCache;
use Foswiki::Search::ResultSet;

=begin TML

---+ package Foswiki::Store::SearchAlgorithms::Forking

Forking implementation of the RCS cache search.

---++ search($searchString, $web, $inputTopicSet, $session, $options) -> \%seen
Search .txt files in $dir for $searchString. See RcsFile::searchInWebContent
for details.

DEPRECATED

=cut

sub search {
    my ( $searchString, $web, $inputTopicSet, $session, $options ) = @_;

    # Default (Forking) search

    # SMELL: I18N: 'grep' must use locales if needed,
    # for case-insensitive searching.
    my $program = '';

    if ( $options->{type}
        && ( $options->{type} eq 'regex' || $options->{wordboundaries} ) )
    {
        $program = $Foswiki::cfg{Store}{EgrepCmd};
    }
    else {
        $program = $Foswiki::cfg{Store}{FgrepCmd};
    }

    if ( $options->{casesensitive} ) {
        $program =~ s/%CS{(.*?)\|.*?}%/$1/g;
    }
    else {
        $program =~ s/%CS{.*?\|(.*?)}%/$1/g;
    }
    if ( $options->{files_without_match} ) {
        $program =~ s/%DET{.*?\|(.*?)}%/$1/g;
    }
    else {
        $program =~ s/%DET{(.*?)\|.*?}%/$1/g;
    }
    if ( $options->{wordboundaries} ) {

# Item5529: Can't use quotemeta because $searchString may be UTF8 encoded
# TODO when testing UTF-8 code, try quotemeta. It should work with a decent perl
        $searchString =~ s#([][|/\\\$\^*()+{};@?.{}])#\\$1#g;
        $searchString = '\b' . $searchString . '\b';
    }

    if ( $Foswiki::cfg{DetailedOS} eq 'MSWin32' ) {

        #try to escape the ^ and "" for native windows grep and apache
        $searchString =~ s/\[\^/[^^/g;

        # Fix escaping and quoting for Windows
        $searchString =~ s#\\#\\\\#g;
        $searchString =~ s#"#\\"#g;
        $searchString = q(") . $searchString . q(");
    }

    my $matches = '';

    #SMELL, TODO, replace with Store call.
    my $sDir = $Foswiki::cfg{DataDir} . '/' . $web . '/';

    # process topics in sets, fix for Codev.ArgumentListIsTooLongForSearch
    my $maxTopicsInSet = 512;    # max number of topics for a grep call
      #TODO: the number is actually dependant on the length of the path to each file
      #SMELL: the following while loop should probably be made by sysCommand, as this is a leaky abstraction.
    ##heck, on pre WinXP its only 2048, post XP its 8191 - http://support.microsoft.com/kb/830473
    if ( $Foswiki::cfg{DetailedOS} eq 'MSWin32' ) {

        #tune the number based on the length of "$sDir/WebSearchAdvanced.txt"
        #30 is a guess - wotamess
        $maxTopicsInSet =
          ( ( 8191 - ( length($program) + length($searchString) + 30 ) ) /
              ( length("$sDir/LongWebSearchAdvanced.txt") + 10 ) );

        #print STDERR "++++++++++++ $maxTopicsInSet \n";
    }

    #    while (my @set = splice( @take, 0, $maxTopicsInSet )) {
    #        @set = map { "$sDir/$_.txt" } @set;
    my @set;
    $inputTopicSet->reset();
    while ( $inputTopicSet->hasNext() ) {
        my $webtopic = $inputTopicSet->next();
        my ( $Iweb, $tn ) =
          Foswiki::Func::normalizeWebTopicName( $web, $webtopic );
        push( @set, "$sDir/$tn.txt" );
        if (
            ( $#set >= $maxTopicsInSet )    #replace with character count..
            || !( $inputTopicSet->hasNext() )
          )
        {
            my ( $m, $exit ) = Foswiki::Sandbox->sysCommand(
                $program,
                TOKEN => $searchString,
                FILES => \@set
            );
            @set = ();

            # man grep: "Normally, exit status is 0 if selected lines are found
            # and 1 otherwise. But the exit status is 2 if an error occurred,
            # unless the -q or --quiet or --silent option is used and a selected
            # line is found."
            if ( $exit > 1 ) {

    #TODO: need to work out a way to alert the admin there is a problem, without
    #      filling up the log files with repeated SEARCH's

# NOTE: we ignore the error, because grep returns an error if it comes across a broken file link
#       or a file it does not have permission to open, so throwing here gives wrong search results.
# throw Error::Simple("$program Grep for '$searchString' returned error")
            }
            $matches .= $m;
        }
    }
    my %seen;

    # Note use of / and \ as dir separators, to support Winblows
    $matches =~
      s/([^\/\\]*?)\.txt(:(.*))?$/push( @{$seen{$1}}, ($3||'') ); ''/gem;

    # Implicit untaint OK; data from grep

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
        my $thisWebNoSearchAll =
          Foswiki::isTrue( $webObject->getPreference('NOSEARCHALL') );

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

    #print STDERR "ForkingSEARCH(".join(', ', @{ $query->{tokens} }).")\n";
    # default scope is 'text'
    $options->{'scope'} = 'text'
      unless ( defined( $options->{'scope'} )
        && $options->{'scope'} =~ /^(topic|all)$/ );

    my $topicSet = $inputTopicSet;
    if ( !defined($topicSet) ) {

        #then we start with the whole web
        #TODO: i'm sure that is a flawed assumption
        my $webObject = Foswiki::Meta->new( $session, $web );
        $topicSet =
          Foswiki::Search::InfoCache::getTopicListIterator( $webObject,
            $options );
    }
    ASSERT( UNIVERSAL::isa( $topicSet, 'Foswiki::Iterator' ) ) if DEBUG;

#print STDERR "######## Forking search ($web) tokens ".scalar(@{$query->{tokens}})." : ".join(',', @{$query->{tokens}})."\n";
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
# http://foswiki.org/Tasks/Item1646 this causes us to use/leak huge amounts of memory if called too often
            $qtoken = quotemeta($qtoken) if ( $options->{'type'} ne 'regex' );

            $topicSet->reset();
            while ( $topicSet->hasNext() ) {
                my $webtopic = $topicSet->next();
                my ( $itrWeb, $topic ) =
                  Foswiki::Func::normalizeWebTopicName( $web, $webtopic );

                if ( $options->{'casesensitive'} ) {

                    # fix for Codev.SearchWithNoPipe
                    #push(@scopeTopicList, $topic) if ( $topic =~ /$qtoken/ );
                    $topicMatches{$topic} = 1 if ( $topic =~ /$qtoken/ );
                }
                else {

                    #push(@scopeTopicList, $topic) if ( $topic =~ /$qtoken/i );
                    $topicMatches{$topic} = 1 if ( $topic =~ /$qtoken/i );
                }
            }
        }

        # scope='text', e.g. grep search on topic text:
        unless ( $options->{'scope'} eq 'topic' ) {
            my $textMatches =
              search( $tokenCopy, $web, $topicSet, $session, $options );

            #bring the text matches into the topicMatch hash
            if ($textMatches) {
                @topicMatches{ keys %$textMatches } = values %$textMatches;
            }
        }

        my @scopeTextList = ();
        if ($invertSearch) {
            $topicSet->reset();
            while ( $topicSet->hasNext() ) {
                my $webtopic = $topicSet->next();
                my ( $Iweb, $topic ) =
                  Foswiki::Func::normalizeWebTopicName( $web, $webtopic );

                if ( $topicMatches{$topic} ) {
                }
                else {
                    push( @scopeTextList, $topic );
                }
            }
        }
        else {

            #TODO: the sad thing about this is we lose info
            @scopeTextList = keys(%topicMatches);
        }

        # reduced topic list for next token
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

Copyright (C) 2002 John Talintyre, john.talintyre@btinternet.com
Copyright (C) 2002-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
