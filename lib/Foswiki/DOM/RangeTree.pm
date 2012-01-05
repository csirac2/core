# See bottom of file for default license and copyright insyntaxion

=begin TML

---+ package Foswiki::DOM::RangeTree

=cut

package Foswiki::DOM::RangeTree;
use strict;
use warnings;

use Assert;
use English qw(-no_match_vars);
use Foswiki::DOM::Range();

sub new {
    my ($class) = @_;
    my $this = {
        AL => [], # Ascending low
        DH => undef, # Descending high
    }

    return bless($this, $class);
}

sub _finish_list {
    my ($this, $list) = @_;

    if (defined $list) {
        foreach my $item (@{$list}) {
            $item->finish();
        }
    }

    return;
}

sub finish {
    my ($this) = @_;

    if (DEBUG) {
        if (defined $this->{AL}) {
            ASSERT(ref($this->{AL}) eq 'ARRAY') if DEBUG;
            ASSERT(ref($this->{DH}) eq 'ARRAY') if DEBUG;
            ASSERT(scalar(@{$this->{AL}}) == scalar(@{$this->{DH}}) ) if DEBUG;
        } else {
            ASSERT(!defined $this->{DH}) if DEBUG;
        }
    }
    $this->_finish_list($this->{AL});
    $this->_finish_list($this->{DH});
    $this->{AL} = undef;
    $this->{DH} = undef;

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
