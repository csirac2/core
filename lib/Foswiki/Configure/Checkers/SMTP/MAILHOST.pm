# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::SMTP::MAILHOST;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check {
    my $this = shift;
    my $n = '';

    return '' if ( !$Foswiki::cfg{EnableEmail} );

    return '' unless ($Foswiki::cfg{Email}{MailMethod} ne "MailProgram" );

    if ( $Foswiki::cfg{Email}{MailMethod} eq 'Net::SMTP::SSL' 
      && $Foswiki::cfg{SMTP}{MAILHOST} !~ m/:[0-9]{2,5}/) {
        $n = $this->WARN("Selected MailMethod $Foswiki::cfg{Email}{MailMethod} might require a custom port number, <code>:465</code>");
    }

    return $n if ($Foswiki::cfg{SMTP}{MAILHOST});

    return $n . $this->ERROR("Hostname or address required for chosen MailMethod $Foswiki::cfg{Email}{MailMethod}.");

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
