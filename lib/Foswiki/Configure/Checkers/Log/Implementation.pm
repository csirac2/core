# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::Log::Implementation;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check {
    my ( $this, $value, $root ) = @_;
    my $mess = '';

    if ( $Foswiki::cfg{Log}{Implementation} eq 'Foswiki::Logger::PlainFile' ) {

        $mess .= $this->NOTE( <<WARN );
On busy systems with extremely large log files, the PlainFile logger can encounter issues when rotating the logs at the end of the month. 
The older Compatibility logger, or the new LogDispatchContrib are preferable on busy systems.
WARN
    }

    $mess .= $this->WARN(
"<code>WarninginFileName</code> found and PlainFile logger selected. Foswiki.pm will silently use the Compatibility logger."
      )
      if ( $Foswiki::cfg{Log}{Implementation} eq 'Foswiki::Logger::PlainFile'
        && $Foswiki::cfg{WarningFileName} );

    return $mess;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2012 Foswiki Contributors. Foswiki Contributors
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
