# See bottom of file for default license and copyright insyntaxion

=begin TML

---+ package Foswiki::DOM::Parser::Scanner

Foswiki::DOM::Parser::Scanner parsers are multi-pass things which treat the
=$input= as a one-dimensional landscape in which to mark various regions with
syntax. During this process, =$input= may be modified - for example, to expand
a %MACRO (replacing its occurence with its result) or to exclude some <verbatim>
content from being processed (by zeroing/null'ing it out).

=$input=

=cut

package Foswiki::DOM::Parser::Scanner;
use strict;
use warnings;

use Assert;
use English qw(-no_match_vars);
use Foswiki::DOM();
use Foswiki::DOM::Parser();
our @ISA = ('Foswiki::DOM::Parser');

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
