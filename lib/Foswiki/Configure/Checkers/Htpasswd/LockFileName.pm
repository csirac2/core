# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::Htpasswd::LockFileName;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check {
    my $this = shift;
    my $e    = '';

    $e .= $this->showExpandedValue( $Foswiki::cfg{Htpasswd}{LockFileName} );

    #NOTE:  If there are any other PasswordManagers that require .htpasswd,
    #       they should be added to this list.
    return $e
      if ( $Foswiki::cfg{PasswordManager} ne 'Foswiki::Users::HtPasswdUser'
        && $Foswiki::cfg{PasswordManager} ne
        'Foswiki::Users::ApacheHtpasswdUser' );

    my $f = $Foswiki::cfg{Htpasswd}{LockFileName};
    Foswiki::Configure::Load::expandValue($f);

    ($f) = $f =~ m/(.*)/;     # Untaint needed to prevent a failure.

    unless ( -e $f ) {
	# lock file does not exist; check it can be created
	my $fh;
	if (!open($fh, ">", $f) || !close($fh)) {
	    $e .= $this->ERROR("$f could not be created: $!");
	}
    } elsif ( ! -f $f || ! -w $f ) {
	# lock file exists but is a directory or is not writable
	$e .= $this->ERROR( "$f is not a writable plain file. ")
    }
    unlink $f;

    return $e;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2012 Foswiki Contributors. Foswiki Contributors
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
# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::Htpasswd::LockFileName;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check {
    my $this = shift;
    my $e    = '';

    $e .= $this->showExpandedValue( $Foswiki::cfg{Htpasswd}{LockFileName} );

    #NOTE:  If there are any other PasswordManagers that require .htpasswd,
    #       they should be added to this list.
    return $e
      if ( $Foswiki::cfg{PasswordManager} ne 'Foswiki::Users::HtPasswdUser'
        && $Foswiki::cfg{PasswordManager} ne
        'Foswiki::Users::ApacheHtpasswdUser' );

    my $f = $Foswiki::cfg{Htpasswd}{LockFileName};
    Foswiki::Configure::Load::expandValue($f);

    unless ( -e $f ) {

        # lock file does not exist; check it can be created
        my $fh;
        if ( !open( $fh, ">", $f ) || !close($fh) ) {
            $e .= $this->ERROR("$f could not be created: $!");
        }
    }
    elsif ( !-f $f || !-w $f ) {

        # lock file exists but is a directory or is not writable
        $e .= $this->ERROR("$f is not a writable plain file. ");
    }
    unlink $f;

    return $e;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2012 Foswiki Contributors. Foswiki Contributors
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
