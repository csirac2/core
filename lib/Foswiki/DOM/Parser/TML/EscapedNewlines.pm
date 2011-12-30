# See bottom of file for default license and copyright insyntaxion

=begin TML

---+ package Foswiki::DOM::Parser::TML::EscapedNewlines

=cut

package Foswiki::DOM::Parser::TML::EscapedNewlines;
use strict;
use warnings;

use Assert;
use English qw(-no_match_vars);
use Foswiki::DOM::Parser::TML();
our @ISA = ('Foswiki::DOM::Parser::TML');

sub TRACE { 0 }

sub priority { return 990; }

=begin TML

---++ ClassMethod scan ( $dom )

Remove escaped newlines from the input buffer, but add them to the DOM as zero-
width nodes.

=cut

sub scan {
    my ( $class, $dom ) = @_;
    my $removed = 0;

    ASSERT( $dom->isa('Foswiki::DOM') ) if DEBUG;
    $dom->{input} =~ s/\\\n/
        my $begin = pos($dom->{input}) - $removed;
        $removed += 2;
        $class->replace_input($dom,
            node_class => 'Foswiki::DOM::Node::EscapedNewLine',
            begin_markup => $begin,
            length => 0,
            do_replace => 0,
            replacement => ''
        );
        /gemx;

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
