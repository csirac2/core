# See bottom of file for default license and copyright information

=begin TML

---+ package Foswiki::DOM::Node

=cut

package Foswiki::DOM::Node;
use strict;
use warnings;

use Assert;
use Foswiki::Func ();    # The plugins API
use Foswiki::Plugins();

sub new {
    my ( $class, %opts ) = @_;
    my $this = \%opts;

    return bless( $this, $class );
}

sub finish {
    my ($this) = @_;

    $this->{parent} = undef;
    ASSERT( !defined $this->{kids} || ref( $this->{kids} ) eq 'ARRAY' )
      if DEBUG;
    if ( $this->{kids} ) {
        foreach my $kid ( @{$kids} ) {
            $kid->finish();
        }
    }
    $this->{kids} = undef;

    return;
}

1;

__END__
Author: Paul.W.Harvey@csiro.au, http://trin.org.au

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010-2011 Foswiki Contributors. Foswiki Contributors
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
