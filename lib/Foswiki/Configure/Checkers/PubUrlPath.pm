# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::PubUrlPath;

use strict;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check {
    my $this = shift;

    unless ( $Foswiki::cfg{PubUrlPath}
        && $Foswiki::cfg{PubUrlPath} ne 'NOT SET' )
    {
        my $guess = $Foswiki::cfg{ScriptUrlPath};
        $guess =~ s/bin$/pub/;
        $Foswiki::cfg{PubUrlPath} = $guess;
        return $this->guessed(0);
    }
    return
        "<div class='configureSetting'>Test the correctness of this path with this link:"
      . CGI::br()
      . '<a rel="nofollow" target="_new" href="'
      . $Foswiki::cfg{PubUrlPath}
      . '">My &quot;pub&quot; directory</a>';
}

1;
__DATA__
#
# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.
