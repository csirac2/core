# See bottom of file for default license and copyright insyntaxion

=begin TML

---+ package Foswiki::DOM::Scanner

A facade which calls upon the scanner class appropriate for the given
=$dom->{input_markup}=

Scanners don't necessarily modify =$dom->{input}=; their main purpose is to
claim regions of this input string. Regions, like the input string are
one-dimensional, having simply a start and end point.

Scanners which want to claim a region exclusively (prevent any further scanning)
may do so by nulling out claimed regions (i.e. chr(0))

These excluded regions must be restored before returning to this facade

=cut

package Foswiki::DOM::Scanner;
use strict;
use warnings;

use Assert;
use English qw(-no_match_vars);
use Foswiki::DOM::Scanner::TML();

my %markups = (
    tml => 'Foswiki::DOM::Scanner::TML'
);

sub scan {
    my ( $class, $dom ) = @_;
    my $markup = $dom->{input_markup};

    ASSERT(exists $markups{$markup});

    return $markups{$markup}->scan($dom);
}

sub trace {
    my ($class, $msg, $level, $callershift) = @_;

    return Foswiki::DOM->trace($msg, $level, $callershift || 1);
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
