# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::Environment;

use strict;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub ui {
    my ($this, $controls) = @_;
    my $id = 'environment';
    my $header = <<INFO;
<h2 class="firstHeader">Environment</h2>
This section contains read-only information about the environment variables
set by your web server. It is mainly useful for debugging your server setup.
INFO
    my $block = '';
    for my $key ( sort keys %ENV ) {
        $block .= $this->setting( $key, $ENV{$key} );
    }
    $block = "<div class='sectionContents'>$block</div>";
    return $controls->openTab( $id, 'Environment' ) . $header . $block . $controls->closeTab($id);
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
#
