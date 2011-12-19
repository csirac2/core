# See bottom of file for default license and copyright insyntaxion

=begin TML

---+ package Foswiki::DOM::Scanner::TML

This is a facade to the various syntaxes which make up TML. It processes each
syntax in a specific order, reflecting their priority

=cut

package Foswiki::DOM::Scanner::TML;
use strict;
use warnings;

use Assert;
use English qw(-no_match_vars);
use Foswiki::DOM::Scanner();
our @ISA = ('Foswiki::DOM::Scanner');

use Foswiki::DOM::Scanner::TML::Verbatim();
#use Foswiki::DOM::Scanner::TML::EscapedNewlines();
#use Foswiki::DOM::Scanner::TML::Macro();
#use Foswiki::DOM::Scanner::TML::XMLExclusive();
#use Foswiki::DOM::Scanner::TML::LineHogs();
#use Foswiki::DOM::Scanner::TML::XML();
#use Foswiki::DOM::Scanner::TML::Para();
#use Foswiki::DOM::Scanner::TML::Link();
#use Foswiki::DOM::Scanner::TML::Style();

my @syntaxes = (

    # No other syntaxes should inspect verbatim blocks
    'Foswiki::DOM::Scanner::TML::Verbatim',

    # No other syntaxes need to see escaped newlines; removed from =$input=
    'Foswiki::DOM::Scanner::TML::EscapedNewlines',

    # No other syntaxes should be inspecting macro expressions
    'Foswiki::DOM::Scanner::TML::Macro',

    # XMLExclusive includes <pre/>, <literal/> and <sticky/>
    'Foswiki::DOM::Scanner::TML::XMLExclusive',

    # Table, List, IndentPara Anchor, Heading, Vbar
    'Foswiki::DOM::Scanner::TML::LineHogs',

    # Xml: <noautolink/>, <dirtyarea/>, <u/>, <s/>, <strike/>.
    'Foswiki::DOM::Scanner::TML::XML',
    'Foswiki::DOM::Scanner::TML::Para',
    'Foswiki::DOM::Scanner::TML::Link',
    'Foswiki::DOM::Scanner::TML::Style'
);

sub scan {
    my ( $class, $dom ) = @_;
    my $previous_priority = 1_000_000;

    foreach my $syntaxClass (@syntaxes) {
        ASSERT( $previous_priority >= $syntaxClass->priority() );
        $previous_priority = $syntaxClass->priority();
        $syntaxClass->scan( $dom );
    }

    return;
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
