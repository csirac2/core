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

use Foswiki::DOM::Parser::TML::Verbatim();
#use Foswiki::DOM::Parser::TML::EscapedNewlines();
#use Foswiki::DOM::Parser::TML::Macro();
#use Foswiki::DOM::Parser::TML::XMLExclusive();
#use Foswiki::DOM::Parser::TML::LineHogs();
#use Foswiki::DOM::Parser::TML::XML();
#use Foswiki::DOM::Parser::TML::Para();
#use Foswiki::DOM::Parser::TML::Link();
#use Foswiki::DOM::Parser::TML::Style();

my @syntaxes = (

    # No other syntaxes should inspect verbatim blocks
    'Foswiki::DOM::Parser::TML::Verbatim',

    # No other syntaxes need to see escaped newlines; removed from =$input=
    'Foswiki::DOM::Parser::TML::EscapedNewlines',

    # No other syntaxes should be inspecting macro expressions
    'Foswiki::DOM::Parser::TML::Macro',

    # XMLExclusive includes <pre/>, <literal/> and <sticky/>
    'Foswiki::DOM::Parser::TML::XMLExclusive',

    # Table, List, IndentPara Anchor, Heading, Vbar
    'Foswiki::DOM::Parser::TML::LineHogs',

    # Xml: <noautolink/>, <dirtyarea/>, <u/>, <s/>, <strike/>.
    'Foswiki::DOM::Parser::TML::XML',
    'Foswiki::DOM::Parser::TML::Para',
    'Foswiki::DOM::Parser::TML::Link',
    'Foswiki::DOM::Parser::TML::Style'
);

sub parse {
    my ( $class, $dom ) = @_;
    my $previous_priority = 1_000_000;

    foreach my $syntaxClass (@syntaxes) {
        ASSERT( $previous_priority >= $syntaxClass->priority() ) if DEBUG;
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
