# See bottom of file for license and copyright information
package Foswiki;

use strict;
use warnings;

#our $SEARCHTERMS = qr/\$(web|topic|parent|text|locked|date|isodate|rev|username|wikiname|wikiusername|createdate|createusername|createwikiname|createwikiusername|summary|changes|formname|formfield|pattern|count|ntopics|nhots|pager)\b/;

sub FOREACH {
    my ( $this, $params, $topicObject ) = @_;

    my @list = split( /,\s*/, $params->{_DEFAULT} || '' );
    my $s;

#TODO: this is a common default that should be extracted into a 'test, default and refine' parameters for all formatResult calls
    $params->{separator} = '$n' unless ( defined( $params->{separator} ) );
    $params->{separator} =
      Foswiki::expandStandardEscapes( $params->{separator} );

    my $type   = $params->{type} || 'topic';
    $type = 'topic'
      unless ( $type eq 'string' );    #only support special type 'string'

    # pass on all attrs, and add some more
    #$params->{_callback} = undef;
    $params->{baseweb}   = $topicObject->web;
    $params->{basetopic} = $topicObject->topic;
    $params->{search}    = $params->{_DEFAULT}
      if defined $params->{_DEFAULT};
    $params->{type} = $this->{prefs}->getPreference('SEARCHVARDEFAULTTYPE')
      unless ( $params->{type} );

    try {
        my $listIterator;

        if ( $type eq 'string' ) {
            require Foswiki::ListIterator;
            $listIterator = new Foswiki::ListIterator( \@list );
        }
        else {

            #from Search::_makeTopicPattern (plus an added . to allow web.topic)
            my @topics = map {
                s/[^\*\_\-\+\.$Foswiki::regex{mixedAlphaNum}]//go;
                s/\*/\.\*/go;
                $_
            } @list;

            require Foswiki::Search::InfoCache;
            $listIterator =
              new Foswiki::Search::InfoCache( $this, $params->{baseweb},
                \@topics );
        }
        my ( $ttopics, $searchResult, $tmplTail ) =
          $this->search->formatResults( undef, $listIterator, $params );
        $s = $searchResult;
    }
    catch Error::Simple with {
        my $message = (DEBUG) ? shift->stringify() : shift->{-text};

        # Block recursions kicked off by the text being repeated in the
        # error message
        $message =~ s/%([A-Z]*[{%])/%<nop>$1/g;
        $s = $this->inlineAlert( 'alerts', 'bad_search', $message );
    };

    return $s;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
