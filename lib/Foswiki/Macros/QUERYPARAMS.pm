# See bottom of file for license and copyright information
package Foswiki;

use strict;
use warnings;
require Foswiki::Macros::ENCODE;

sub QUERYPARAMS {
    my ( $this, $params ) = @_;
    return '' unless $this->{request};
    my $format =
      defined $params->{format}
      ? $params->{format}
      : '$name=$value';
    my $separator = defined $params->{separator} ? $params->{separator} : "\n";
    my $encoding = $params->{encoding} || 'safe';

    my @list;
    foreach my $name ( $this->{request}->param() ) {

        # Issues multi-valued parameters as separate hiddens
        my $value = $this->{request}->param($name);
        $value = '' unless defined $value;
        $name  = $this->ENCODE( { type => $encoding, _DEFAULT => $name } );
        $value = $this->ENCODE( { type => $encoding, _DEFAULT => $value } );

        my $entry = $format;
        $entry =~ s/\$name/$name/g;
        $entry =~ s/\$value/$value/;
        push( @list, $entry );
    }
    return join( $separator, @list );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2009 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.
Based on parts of Ward Cunninghams original Wiki and JosWiki.
Copyright (C) 1998 Markus Peter - SPiN GmbH (warpi@spin.de)
Some changes by Dave Harris (drh@bhresearch.co.uk) incorporated

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
