# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Serialise::Perl

This is a Data::Dumper style

#TODO: rename?

=cut

package Foswiki::Serialise::Perl;

use strict;
use warnings;
use Data::Dumper;

=begin TML

---++ ClassMethod new( $class,  ) -> $cereal

=cut

sub new {
    my $class = shift;
    my $this = bless( {}, $class );
    return $this;
}

sub write {
    my $module = shift;
    my ( $session, $result ) = @_;

    local $Data::Dumper::Indent = 0;
    local $Data::Dumper::Terse  = 1;
    return Data::Dumper->Dump( [$result] );
}

sub read {
    my $module = shift;
    die 'not implemented';
}

1;
__END__
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
