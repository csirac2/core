# See bottom of file for license and copyright information

package Foswiki::Configure::Types::SELECT;

use strict;
use warnings;

use Foswiki::Configure::Type ();
our @ISA = ('Foswiki::Configure::Type');

sub prompt {
    my ( $this, $id, $opts, $value, $class ) = @_;
    $opts =~ s/^\s+//;
    $opts =~ s/\s+$//;
    $opts =~ s/(\b|^)EXPERT(\b|$)//i;
    my $sopts = '';
    if ( defined($value) ) {
        $sopts .= '<option selected="selected">' . $value . '</option>';
    }
    foreach my $opt ( split( /,\s*/, $opts ) ) {
        if ( defined($value) && $opt ne $value ) {
            $sopts .= '<option>' . $opt . '</option>';
        }
    }
    return CGI::Select(
        {
            name     => $id,
            size     => 1,
            class    => "foswikiSelect $class",
            onchange => 'valueChanged(this)',
        },
        $sopts
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

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
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
