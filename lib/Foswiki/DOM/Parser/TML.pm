# See bottom of file for default license and copyright insyntaxion

=begin TML

---+ package Foswiki::DOM::Parser::TML

This is a facade to the various syntaxes which make up TML. It processes each
syntax in a specific order, reflecting their priority

=cut

package Foswiki::DOM::Parser::TML;
use strict;
use warnings;

use Assert;
use English qw(-no_match_vars);
use Foswiki::DOM::Parser::Scanner();
our @ISA = ('Foswiki::DOM::Parser::Scanner');

sub TRACE { 0 }

sub TRACEEXCLUDE { 0 }

use Foswiki::DOM::Parser::TML::Verbatim();
use Foswiki::DOM::Parser::TML::EscapedNewlines();

use Foswiki::DOM::Parser::TML::Macro();

#use Foswiki::DOM::Parser::TML::XMLExclusive();
#use Foswiki::DOM::Parser::TML::LineHogs();
#use Foswiki::DOM::Parser::TML::XML();
#use Foswiki::DOM::Parser::TML::Link();
#use Foswiki::DOM::Parser::TML::Style();

my @syntaxes = (

    # No other syntax should inspect verbatim blocks
    'Foswiki::DOM::Parser::TML::Verbatim',

    # No other syntax need to see escaped newlines; deleted from =$input=
    'Foswiki::DOM::Parser::TML::EscapedNewlines',

    # No other syntax should be inspecting macro expressions
    'Foswiki::DOM::Parser::TML::Macro',

    # XMLExclusive includes <pre/>, <literal/> and <sticky/>
    #    'Foswiki::DOM::Parser::TML::XMLExclusive',

    # Table, List, IndentPara Anchor, Heading, Vbar
    #    'Foswiki::DOM::Parser::TML::LineHogs',

    # Xml: <noautolink/>, <dirtyarea/>, <u/>, <s/>, <strike/>.
    #    'Foswiki::DOM::Parser::TML::XML',
    #    'Foswiki::DOM::Parser::TML::Link',
    #    'Foswiki::DOM::Parser::TML::Style'
);

sub parse {
    my ( $class, $dom ) = @_;
    my $previous_priority = 1_000_000;

    foreach my $syntaxClass (@syntaxes) {
        ASSERT( $previous_priority >= $syntaxClass->priority() ) if DEBUG;
        $previous_priority = $syntaxClass->priority();
        $syntaxClass->scan($dom);
        $class->trace( [ "Parsed $syntaxClass, DOM:", $dom ] );
    }

    return;
}

sub claim {
    my ( $class, $dom, %opts ) = @_;
    ASSERT( defined $opts{begin} )  if DEBUG;
    ASSERT( defined $opts{length} ) if DEBUG;
    ASSERT( defined $opts{end} || $opts{length} == 0 )
      if DEBUG;
    ASSERT( !defined $opts{end} || $opts{end} >= $opts{begin} ) if DEBUG;
    ASSERT( !defined $opts{end} || $opts{end} - $opts{begin} == $opts{length} )
      if DEBUG;

    $class->trace(
        "CLAIMING $opts{length}; $opts{begin} - " . ( $opts{end} || 0 ) )
      if TRACE;

    return;
}

=begin TML

---++ ClassMethod exclude($dom, %opts) -> $mask

Replaces a part of the =$dom->{input}= buffer with
=$Foswiki::DOM::Parser::Scanner::$EXCLUDE_CHAR=

The goal is to exclude any of the content from being processed by subsequent
syntax parsers (Eg. <verbatim>, <literal>, etc).

The content is masked out rather than removed to avoid re-calculating already
claimed offsets/ranges within the =$dom->{input}= buffer

=$mask= is returned so this can be used in a
=s/pattern/$dom->exclude()/gemx= style regex. The Foswiki::DOM::Node
added to the tree uses the normal range =%opts=:
   * =node_class=  - Foswiki::DOM node class to use in the DOM tree
   * =do_replace=  - boolean, true if we want the =$dom->{input}= buffer to be
     modified with =$opts{replacement}= replacing =$opts{begin}..$opts{end}=
   * =begin=  - start of =$dom->{input}= which the replaced value addresses
   * =end=    - end of =$dom->{input}= which the replaced value addresses
   * =length= - =end - begin=

=cut

sub exclude {
    my ( $class, $dom, %opts ) = @_;
    ASSERT( defined $opts{node_class} )                  if DEBUG;
    ASSERT( defined $opts{do_replace} )                  if DEBUG;
    ASSERT( defined $opts{begin} )                       if DEBUG;
    ASSERT( defined $opts{length} )                      if DEBUG;
    ASSERT( defined $opts{end} )                         if DEBUG;
    ASSERT( $opts{end} >= $opts{begin} )                 if DEBUG;
    ASSERT( $opts{length} > 0 )                          if DEBUG;
    ASSERT( $opts{length} == $opts{end} - $opts{begin} ) if DEBUG;
    my $mask = $Foswiki::DOM::Parser::Scanner::EXCLUDE_CHAR x ( $opts{length} );

    ASSERT( $opts{length} == length($mask) ) if DEBUG;
    $class->trace(
        [
            "EXCLUDING $opts{length}; $opts{begin} - $opts{end}, before: ",
            $dom->{input}
        ]
    ) if TRACEEXCLUDE;
    if ( $opts{do_replace} ) {
        substr( $dom->{input}, $opts{begin}, $opts{length}, $mask );
        $class->trace( [ 'EXCLUDE-REPLACE after: ', $dom->{input} ] )
          if TRACEEXCLUDE;
    }
    else {

        # Can't do an "after" if the replacement hasn't happened yet
        # (inside an s///)
        $class->trace('EXCLUDE-EXTERNAL-REPLACE') if TRACEEXCLUDE;
    }

    $class->claim( $dom, %opts );

    return $mask;
}

=begin TML

---++ ClassMethod replace_input($dom, %opts) -> $opts{replace}

Replaces a part of the =$dom->{input}= buffer with =$opts{replacement}=.

=$opts{replacement}= is returned so this can be used in a
=s/pattern/$dom->replace_input()/gemx= style regex. The Foswiki::DOM::Node
added to the tree uses the normal range =%opts=:
   * =node_class=  - Foswiki::DOM node class to use in the DOM tree
   * =replacement= - string to be inserted; also the return value
   * =do_replace=  - boolean, true if we want the =$dom->{input}= buffer to be
     modified with =$opts{replacement}= replacing =$opts{begin}..$opts{end}=
   * =begin=  - start of =$dom->{input}= which the replaced value addresses
   * =end=    - end of =$dom->{input}= which the replaced value addresses
   * =length= - =end - begin=

=cut

sub replace_input {
    my ( $class, $dom, %opts ) = @_;

    ASSERT( defined $opts{node_class} ) if DEBUG;
    ASSERT( defined $opts{do_replace} ) if DEBUG;
    ASSERT( defined $opts{begin} )      if DEBUG;
    ASSERT( defined $opts{length} )     if DEBUG;
    ASSERT( $opts{length} eq length( $opts{replacement} ) ) if DEBUG;

    # Zero-width replacement; optimization assumes replacement already done
    if ( !defined $opts{end} ) {
        ASSERT( $opts{length} == 0 ) if DEBUG;
        ASSERT( !$opts{do_replace} ) if DEBUG;
        $class->trace("REMOVED into a zero-width token @ $opts{begin}")
          if TRACE;
    }
    else {
        ASSERT( $opts{end} >= $opts{begin} ) if DEBUG;
        ASSERT( $opts{end} - $opts{begin} == $opts{length} ) if DEBUG;
    }
    if ( $opts{do_replace} ) {
        substr( $opts{input}, $opts{begin}, $opts{length}, $opts{replacement} );
        $class->trace("REMOVING $opts{length}: $opts{begin} - $opts{end}")
          if TRACE;
    }

    return $opts{replacement};
}

1;

__END__
Author: Paul.W.Harvey@csiro.au, http://trin.org.au

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2011-2011 Foswiki Contributors. Foswiki Contributors
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
