# See bottom of file for license and copyright information

package Foswiki::Configure::UIs::FINDEXTENSIONS;

use strict;

use Foswiki::Configure::UIs::Section ();
our @ISA = ('Foswiki::Configure::UIs::Section');
use Foswiki::Configure::Type ();

sub close_html {
    my ( $this, $section, $root ) = @_;

    # Check that the extensions UI is loadable
    my $bad = 0;
    foreach my $module qw(Foswiki::Configure::UIs::EXTEND)
    {
        eval "use $module ()";
        if ($@) {
            $bad = 1;
            last;
        }
    }
    my $actor;
    if ( !$bad ) {

        # Can't use a submit here, because if we do, it is invoked when
        # the user presses Enter in a text field.
        my @script = File::Spec->splitdir( $ENV{SCRIPT_NAME} || 'THISSCRIPT' );
        my $scriptName = pop(@script);
        $scriptName =~ s/.*[\/\\]//;    # Fix for Item3511, on Win XP

        $actor = CGI::a(
            {
                href      => $scriptName . '?action=FindMoreExtensions',
                class     => 'foswikiSubmit',
                accesskey => 'P'
            },
            'Find More Extensions'
        );
    }
    else {
        $actor = $this->WARN(<<MESSAGE);
Cannot load the extensions installer.
Check 'Perl Modules' in the 'CGI Setup' section above, and install any
missing modules required for the Extensions Installer.
MESSAGE
    }
    return <<INFO . $this->SUPER::close_html($section, $root);
<div class="configureRow foswikiHelp">
Click to consult online extensions repositories for
new extensions. <strong>If you made any changes, save them first!</strong>
<br />$actor
</div>
INFO
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
