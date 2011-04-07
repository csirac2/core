# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Query::OP_comma
List-building n-ary operator.

=cut

package Foswiki::Query::OP_comma;

use strict;
use warnings;

use Foswiki::Query::OP ();
our @ISA = ('Foswiki::Query::OP');

sub new {
    my $class = shift;
    # Treated as arity 2 for parsing, but folds to n-ary
    return $class->SUPER::new(
	arity => 2, canfold => 1,
	name => ',',
	prec => 400,
	canfold => 1 );
}

sub evaluate {
    my $this = shift;
    my $node = shift;
    my @res;
    foreach my $p (@{$node->{params}}) {
	my $a = $p->evaluate(@_);
	if (ref($a) eq 'ARRAY') {
	    push(@res, @$a);
	} else {
	    push(@res, $a);
	}
    }
    return \@res;
}

1;
__END__
Author: Crawford Currie http://c-dot.co.uk

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010 Foswiki Contributors. Foswiki Contributors
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
