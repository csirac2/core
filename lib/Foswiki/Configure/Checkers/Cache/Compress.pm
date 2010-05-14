# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::Cache::Compress;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check {
    my $this = shift;

    if ( $Foswiki::cfg{HttpCompress} != $Foswiki::cfg{Cache}{Compress} ) {
        my $httpComp  = $Foswiki::cfg{HttpCompress}    ? 'enabled' : 'disabled';
        my $cacheComp = $Foswiki::cfg{Cache}{Compress} ? 'enabled' : 'disabled';
        return $this->WARN(
            <<EOF
{HttpCompress} is $httpComp, but {Cache}{Compress} is $cacheComp. Doing
so means the compression / decompression will be done on the fly, and not
cached. It might make sense enabling one or disabling the other, unless you really
know what you're doing.
EOF
        );
    }
    return '';
}

1;
__END__
#
# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008-2010 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
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
