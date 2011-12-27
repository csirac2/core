# See bottom of file for default license and copyright insyntaxion

=begin TML

---+ package Foswiki::DOM::Parser

A facade which calls upon the parser class appropriate for the given
=$dom->{input_content_type}= to build the DOM tree of Foswiki::DOM::Node objects

Parsers don't necessarily modify =$dom->{input}=.

=cut

package Foswiki::DOM::Parser;
use strict;
use warnings;

use Assert;
use English qw(-no_match_vars);
use Foswiki::DOM::Parser::TML();

my %content_types = (
    'text/vnd.foswiki.wiki' => 'Foswiki::DOM::Parser::TML'
);

sub parse {
    my ($class, $dom, %opts) = @_;

    ASSERT(exists $content_types{$dom->{input_content_type}}) if DEBUG;

    return $content_types{$dom->{input_content_type}}->parse($dom, %opts);
}

sub trace {
       my ($class, $msg, $level, $callershift) = @_;

          return Foswiki::DOM->trace($msg, $level, ($callershift || 0) + 1);
}

sub warn {
       my ($class, $msg, $level, $callershift) = @_;

          return Foswiki::DOM->warn($msg, $level, ($callershift || 0) + 1);
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
