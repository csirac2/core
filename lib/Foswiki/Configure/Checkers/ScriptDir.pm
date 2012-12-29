# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::ScriptDir;

use strict;
use warnings;

use Foswiki::Configure::Checkers::PATH ();
our @ISA = ('Foswiki::Configure::Checkers::PATH');

# check() is handled by the default checker.

# feedback is special for scripts

sub provideFeedback {
    my $this = shift;
    my ( $valobj, $button, $label ) = @_;

    $this->{FeedbackProvided} = 1;

    my $e = $button ? $this->check($valobj) : '';

    delete $this->{FeedbackProvided};

    unless ( $e =~ /Error:/ ) {
        $e .= _checkBinDir( $this, $this->getCfg('{ScriptDir}') );
    }

    if ( $this->{GuessedValue} ) {
        $e .=
          $this->FB_VALUE( '{ScriptDir}',
            ( delete $this->{GuessedValue} || '' ) );
    }

    return wantarray ? ( $e, 0 ) : $e;
}

sub _checkBinDir {
    my ( $this, $dir ) = @_;
    my $ext = $Foswiki::cfg{ScriptSuffix} || '';
    my $errs = '';
    unless ( opendir( D, $dir ) ) {
        return $this->ERROR(<<HERE);
Cannot open '$dir' for read ($!) - check it exists, and that permissions are correct.
HERE
    }
    foreach my $script ( grep { -f "$dir/$_" && /^\w+(\.\w+)?$/ } readdir D ) {
        my $err = '';

        #  If a script suffix is set, make sure all scripts have one
        if (   $ext
            && $script !~ /$ext$/
            && $script !~ /\.cfg$/ )
        {
            $err .= <<HERE;
<li>is missing the configured script suffix ($ext).\n
HERE
        }
        if (  !$ext
            && $script =~ /(\..*)$/
            && $script !~ /\.cfg$/
            && $script !~ /\.fcgi$/ )
        {
            $err .= <<HERE;
<li>has a suffix ($1), but no script suffix is configured.\n
HERE
        }

        #  Verify that scripts are executable
        if (   $^O ne 'MSWin32'
            && $script !~ /\.cfg$/
            && !-x "$dir/$script" )
        {
            $err .= <<HERE;
<li>permissions do not include eXecute.  It might not be an executable script.\n
HERE
        }
        if ($err) {
            $errs .= $this->WARN("$script:<ul>$err</ul>");
        }
    }
    closedir(D);
    return $errs;
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
