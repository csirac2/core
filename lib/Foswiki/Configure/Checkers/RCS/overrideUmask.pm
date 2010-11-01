# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::RCS::overrideUmask;
use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

use strict;
use warnings;

sub check {
    my $this = shift;
    my $e;

    my $reqUmask = ( oct(777) - ($Foswiki::cfg{RCS}{dirPermission}|$Foswiki::cfg{RCS}{filePermission}));
    my $oReqUmask = sprintf( '%03o', $reqUmask );

    if ( $Foswiki::cfg{RCS}{overrideUmask} ) {
        $e = $this->NOTE(<<PERM1);
The system umask will be overriden to $oReqUmask.
PERM1
    }
    else {
        my $sysUmask = umask;
        my $oSysUmask = sprintf( '%03o', $sysUmask );
        my $oDirPermission = sprintf( '%03o', $Foswiki::cfg{RCS}{dirPermission}  );
        my $oFilePermission = sprintf( '%03o', $Foswiki::cfg{RCS}{filePermission}  );
        $e = $this->ERROR(<<PERM2);
The system umask ($oSysUmask) is not compatible with the configured directory and file permissions.
A umask of $oReqUmask is required to support the configured Directory and File masks of $oDirPermission and $oFilePermission.
Enable this setting to have the Foswiki override the umask to be compatible with your configured permissions.
PERM2
    }

    return $e;
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
