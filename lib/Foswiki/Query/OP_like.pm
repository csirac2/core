# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Query::OP_like

=cut

package Foswiki::Query::OP_like;

use strict;

use Foswiki::Query::BinaryOP ();
our @ISA = ('Foswiki::Query::BinaryOP');

sub new {
    my $class = shift;
    return $class->SUPER::new( name => '~', prec => 500 );
}

sub evaluate {
    my $this = shift;
    my $node = shift;
    return $this->evalTest(
        $node,
        \@_,
        sub {
            my $expr = quotemeta( $_[1] );

            # quotemeta will have escapes * and ? wildcards
            $expr =~ s/\\\?/./g;
            $expr =~ s/\\\*/.*/g;
            defined( $_[0] )
              && defined( $_[1] )
              && $_[0] =~ m/^$expr$/s ? 1 : 0;
        }
    );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2005-2007 TWiki Contributors. All Rights Reserved.
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

Author: Crawford Currie http://c-dot.co.uk
